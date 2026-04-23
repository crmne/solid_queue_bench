module Bench
  module DatabaseWorkload
    ACCOUNT_COUNT = 40
    BUCKET_COUNT = 25
    ROWS_PER_BUCKET = 50
    DATA_POINT_COUNT = ACCOUNT_COUNT * BUCKET_COUNT * ROWS_PER_BUCKET
    INSERT_BATCH_SIZE = 1_000
    CATEGORIES = %w[report sync ledger cache].freeze

    module_function

    def prepare_data!
      BenchmarkDataPoint.connection_pool.with_connection do
        return if BenchmarkDataPoint.count == DATA_POINT_COUNT

        BenchmarkDataPoint.delete_all
        seed_data_points!
      end
    end

    def db_queries(payload)
      execute_sequence(payload, query_delay_ms: payload.fetch(:duration_ms, 0))
    end

    def db_transaction(payload)
      execute_sequence(payload, query_delay_ms: payload.fetch(:duration_ms, 0), wrap_in_transaction: true)
    end

    def db_mixed(payload)
      state = build_state(payload, query_delay_ms: 0)

      perform_reads(state, hold_connection: false)
      response = Bench::Workloads.http_request(payload)
      state[:http_delay_ms] = response.fetch("duration_ms", payload.fetch(:duration_ms))
      perform_writes(state, hold_connection: false)
    end

    def execute_sequence(payload, query_delay_ms:, wrap_in_transaction: false)
      state = build_state(payload, query_delay_ms:)

      if wrap_in_transaction
        ApplicationRecord.transaction do
          perform_reads(state, hold_connection: true)
          perform_writes(state, hold_connection: true)
        end
      else
        perform_reads(state, hold_connection: false)
        perform_writes(state, hold_connection: false)
      end
    end

    def build_state(payload, query_delay_ms:)
      reads = Integer(payload.fetch(:reads))
      writes = Integer(payload.fetch(:writes))
      benchmark_execution_id = Integer(payload.fetch(:benchmark_execution_id))
      query_delay_ms = Integer(query_delay_ms)

      raise ArgumentError, "reads must be >= 0" if reads.negative?
      raise ArgumentError, "writes must be >= 0" if writes.negative?
      raise ArgumentError, "duration_ms must be >= 0" if query_delay_ms.negative?

      {
        benchmark_execution_id: benchmark_execution_id,
        execution_seed: benchmark_execution_id,
        reads: reads,
        writes: writes,
        query_delay_s: query_delay_ms.to_f / 1000.0,
        read_summaries: [],
        total_rows: 0,
        total_amount_cents: 0,
        total_quantity: 0,
        http_delay_ms: nil
      }
    end

    def perform_reads(state, hold_connection:)
      state[:reads].times do |read_index|
        summary = with_database_connection(hold_connection:) do |connection|
          fetch_summary(
            connection,
            account_key: account_key_for(state, read_index),
            bucket: bucket_for(state, read_index),
            query_delay_s: state[:query_delay_s]
          )
        end

        state[:read_summaries] << summary
        state[:total_rows] += summary[:matched_rows]
        state[:total_amount_cents] += summary[:total_amount_cents]
        state[:total_quantity] += summary[:total_quantity]
      end
    end

    def perform_writes(state, hold_connection:)
      state[:writes].times do |write_index|
        summary = summary_for_write(state, write_index)
        now = Time.current

        with_database_connection(hold_connection:) do |_connection|
          BenchmarkWriteEvent.insert_all!([
            {
              benchmark_execution_id: state[:benchmark_execution_id],
              write_index: write_index,
              account_key: summary[:account_key],
              bucket: summary[:bucket],
              matched_rows: state[:total_rows],
              total_amount_cents: state[:total_amount_cents] + write_index,
              total_quantity: state[:total_quantity],
              http_delay_ms: state[:http_delay_ms],
              created_at: now,
              updated_at: now
            }
          ])
        end
      end
    end

    def with_database_connection(hold_connection:)
      if hold_connection
        yield ApplicationRecord.connection
      else
        ApplicationRecord.connection_pool.with_connection do |connection|
          yield connection
        end
      end
    end

    def fetch_summary(connection, account_key:, bucket:, query_delay_s:)
      sql = if query_delay_s.positive?
        <<~SQL
          WITH filtered AS (
            SELECT amount_cents, quantity, sequence, flagged
            FROM #{BenchmarkDataPoint.table_name}
            WHERE account_key = #{account_key} AND bucket = #{bucket}
          ),
          delay AS MATERIALIZED (
            SELECT pg_sleep(#{format("%.3f", query_delay_s)})
          )
          SELECT
            COUNT(*)::integer AS matched_rows,
            COALESCE(SUM(amount_cents), 0)::bigint AS total_amount_cents,
            COALESCE(SUM(quantity), 0)::bigint AS total_quantity,
            COALESCE(MAX(sequence), 0)::integer AS max_sequence,
            COALESCE(SUM(CASE WHEN flagged THEN 1 ELSE 0 END), 0)::integer AS flagged_rows
          FROM filtered
          CROSS JOIN delay
        SQL
      else
        <<~SQL
          SELECT
            COUNT(*)::integer AS matched_rows,
            COALESCE(SUM(amount_cents), 0)::bigint AS total_amount_cents,
            COALESCE(SUM(quantity), 0)::bigint AS total_quantity,
            COALESCE(MAX(sequence), 0)::integer AS max_sequence,
            COALESCE(SUM(CASE WHEN flagged THEN 1 ELSE 0 END), 0)::integer AS flagged_rows
          FROM #{BenchmarkDataPoint.table_name}
          WHERE account_key = #{account_key} AND bucket = #{bucket}
        SQL
      end

      row = connection.select_one(sql, "Bench::DatabaseWorkload")

      {
        account_key: account_key,
        bucket: bucket,
        matched_rows: row.fetch("matched_rows").to_i,
        total_amount_cents: row.fetch("total_amount_cents").to_i,
        total_quantity: row.fetch("total_quantity").to_i,
        max_sequence: row.fetch("max_sequence").to_i,
        flagged_rows: row.fetch("flagged_rows").to_i
      }
    end

    def summary_for_write(state, write_index)
      return state[:read_summaries].fetch(write_index % state[:read_summaries].size) if state[:read_summaries].any?

      {
        account_key: account_key_for(state, write_index),
        bucket: bucket_for(state, write_index)
      }
    end

    def account_key_for(state, offset)
      ((state[:execution_seed] + offset) % ACCOUNT_COUNT) + 1
    end

    def bucket_for(state, offset)
      (((state[:execution_seed] * 7) + offset) % BUCKET_COUNT) + 1
    end

    def seed_data_points!
      now = Time.current
      rows = []

      ACCOUNT_COUNT.times do |account_offset|
        account_key = account_offset + 1

        BUCKET_COUNT.times do |bucket_offset|
          bucket = bucket_offset + 1

          ROWS_PER_BUCKET.times do |sequence_offset|
            sequence = sequence_offset + 1
            rows << {
              account_key: account_key,
              bucket: bucket,
              sequence: sequence,
              amount_cents: ((account_key * 997) + (bucket * 61) + (sequence * 17)) % 9_000 + 100,
              quantity: ((account_key + bucket + sequence) % 9) + 1,
              flagged: ((sequence + bucket) % 11).zero?,
              category: CATEGORIES[(account_key + bucket + sequence) % CATEGORIES.length],
              created_at: now,
              updated_at: now
            }

            next unless rows.size >= INSERT_BATCH_SIZE

            BenchmarkDataPoint.insert_all!(rows)
            rows.clear
          end
        end
      end

      BenchmarkDataPoint.insert_all!(rows) if rows.any?
    end
  end
end

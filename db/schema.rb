# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_195809) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "benchmark_data_points", force: :cascade do |t|
    t.integer "account_key", null: false
    t.integer "bucket", null: false
    t.integer "sequence", null: false
    t.integer "amount_cents", null: false
    t.integer "quantity", null: false
    t.boolean "flagged", default: false, null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_key", "bucket", "sequence"], name: "index_benchmark_data_points_on_account_bucket_sequence"
    t.index ["bucket", "category"], name: "index_benchmark_data_points_on_bucket_and_category"
  end

  create_table "benchmark_executions", force: :cascade do |t|
    t.string "active_job_id"
    t.bigint "benchmark_run_id", null: false
    t.datetime "created_at", null: false
    t.datetime "enqueued_at", null: false
    t.string "error_class"
    t.text "error_message"
    t.datetime "finished_at"
    t.integer "job_index", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.integer "worker_pid"
    t.string "workload", null: false
    t.integer "child_jobs_enqueued", default: 0, null: false
    t.integer "child_jobs_finished", default: 0, null: false
    t.integer "child_jobs_failed", default: 0, null: false
    t.datetime "last_child_enqueued_at"
    t.datetime "last_child_finished_at"
    t.index ["active_job_id"], name: "index_benchmark_executions_on_active_job_id"
    t.index ["benchmark_run_id", "job_index"], name: "index_benchmark_executions_on_benchmark_run_id_and_job_index", unique: true
    t.index ["benchmark_run_id"], name: "index_benchmark_executions_on_benchmark_run_id"
  end

  create_table "benchmark_runs", force: :cascade do |t|
    t.float "avg_cpu_pct"
    t.integer "avg_rss_kb"
    t.integer "concurrency", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "enqueued_at"
    t.string "concurrency_model", null: false
    t.integer "jobs_count", null: false
    t.float "jobs_per_second"
    t.string "name", null: false
    t.text "notes"
    t.jsonb "payload", default: {}, null: false
    t.float "peak_cpu_pct"
    t.integer "peak_rss_kb"
    t.integer "processes", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.float "wall_time_s"
    t.string "workload", null: false
    t.string "backend", default: "solid_queue", null: false
  end

  create_table "benchmark_write_events", force: :cascade do |t|
    t.bigint "benchmark_execution_id", null: false
    t.integer "write_index", null: false
    t.integer "account_key", null: false
    t.integer "bucket", null: false
    t.integer "matched_rows", default: 0, null: false
    t.bigint "total_amount_cents", default: 0, null: false
    t.integer "total_quantity", default: 0, null: false
    t.integer "http_delay_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benchmark_execution_id", "write_index"], name: "idx_on_benchmark_execution_id_write_index_c4e0180f6c", unique: true
    t.index ["benchmark_execution_id"], name: "index_benchmark_write_events_on_benchmark_execution_id"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ruby_llm_model_id"
    t.bigint "benchmark_execution_id"
    t.boolean "cancelled", default: false, null: false
    t.index ["benchmark_execution_id"], name: "index_chats_on_benchmark_execution_id"
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "role", null: false
    t.text "content"
    t.text "thinking_text"
    t.text "thinking_signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.boolean "cache_until_here", default: false, null: false
    t.string "finish_reason"
    t.jsonb "citations"
    t.jsonb "server_tool_calls"
    t.jsonb "raw_content"
    t.jsonb "raw_reasoning"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "provider_batch_id", null: false
    t.string "provider", null: false
    t.string "status", null: false
    t.string "raw_status"
    t.boolean "completed", default: false, null: false
    t.string "chat_type"
    t.string "batch_protocol"
    t.jsonb "chat_ids", default: []
    t.jsonb "request_counts"
    t.jsonb "reported_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_mcp_credentials", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "key", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ruby_llm_mcp_credentials_on_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_mcp_credentials_on_owner"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.jsonb "modalities", default: {}
    t.jsonb "capabilities", default: []
    t.jsonb "pricing", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "unlisted_at"
    t.index ["capabilities"], name: "index_ruby_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["modalities"], name: "index_ruby_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_provider_files", force: :cascade do |t|
    t.string "blob_key", null: false
    t.string "provider", null: false
    t.string "account", null: false
    t.text "file_id", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_key", "provider", "account"], name: "index_ruby_llm_provider_files_uniqueness", unique: true
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "message_id", null: false
    t.string "message_type", null: false
    t.string "result_type"
    t.bigint "result_id"
    t.string "approval"
    t.boolean "remote", default: false, null: false
    t.jsonb "mcp_state"
    t.jsonb "mcp_result"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.string "chat_type"
    t.bigint "chat_id"
    t.string "message_type"
    t.bigint "message_id"
    t.string "operation", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "status", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cache_read_tokens"
    t.integer "cache_write_tokens"
    t.integer "thinking_tokens"
    t.decimal "input_cost", precision: 16, scale: 10
    t.decimal "output_cost", precision: 16, scale: 10
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "server_tool_use"
    t.string "owner_type"
    t.bigint "owner_id"
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_usages_on_owner"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation::text = ANY (ARRAY['chat'::text, 'embedding'::text, 'moderation'::text, 'image'::text, 'speech'::text, 'transcription'::text, 'ocr'::text, 'rerank'::text, 'judgment'::text, 'video'::text, 'research'::text])"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "benchmark_executions", "benchmark_runs"
  add_foreign_key "benchmark_write_events", "benchmark_executions"
  add_foreign_key "chats", "benchmark_executions"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "messages", "chats"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end

require "digest"
require "socket"

module Bench
  module Environment
    module_function

    def metadata
      {
        ruby_description: RUBY_DESCRIPTION,
        dependencies: Bundler.load.specs.sort_by(&:name).to_h do |spec|
          source = spec.source
          info = { version: spec.version.to_s }
          info[:revision] = source.revision if source.respond_to?(:revision)
          [spec.name, info]
        end,
        lockfile_sha256: Digest::SHA256.file(Bundler.default_lockfile).hexdigest,
        llm_adapter: ENV.fetch("BENCH_LLM_ADAPTER", "net_http"),
        hostname: Socket.gethostname,
        cpu: File.read("/proc/cpuinfo")[/^model name\s*:\s*(.+)$/, 1],
        postgres_version: ActiveRecord::Base.connection.select_value("SHOW server_version"),
        postgres_max_connections: ActiveRecord::Base.connection.select_value("SHOW max_connections").to_i
      }
    end
  end
end

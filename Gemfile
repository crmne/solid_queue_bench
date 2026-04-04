source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
gem "solid_queue", path: "../solid_queue"
gem "async"
gem "async-http"
gem "async-job-adapter-active_job", git: "https://github.com/crmne/async-job-adapter-active_job.git", branch: "fix-threaded-health-signals"
gem "async-job-processor-redis", git: "https://github.com/crmne/async-job-processor-redis.git", branch: "fix-threaded-heartbeats"
gem "csv"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

gem "ruby_llm", "~> 1.14"

gem "turbo-rails", "~> 2.0"

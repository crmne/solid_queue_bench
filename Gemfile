source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
gem "solid_queue", "~> 1.7"
gem "async"
gem "async-http"
gem "async-job-adapter-active_job"
gem "async-job-processor-redis"
gem "csv"
gem "vega"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

if ENV["BUNDLE_GEMFILE"]&.end_with?("Gemfile.main")
  gem "ruby_llm", git: "https://github.com/crmne/ruby_llm.git", branch: "main"
else
  gem "ruby_llm", "~> 2.0.0"
end
gem "faraday-net_http_persistent"
gem "async-http-faraday"

gem "turbo-rails", "~> 2.0"

gem "dotenv", "~> 3.2"

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 7.0'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'
# Use Puma as the app server
gem 'puma', '~> 6.0'
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

gem 'devise'
gem 'rack-attack' # Rate limiting / throttling for auth and public endpoints
gem 'prawn' # PDF generation
gem 'prawn-table' # Table support for PDFs

# Gmail integration: OAuth2 token handling + Gmail API client for sending mail
gem 'googleauth' # Signet OAuth2 client + token refresh
gem 'google-apis-gmail_v1' # Gmail API client

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  gem 'simplecov', require: false
  gem 'shoulda-matchers'
  gem 'database_cleaner-active_record'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Ruby linter
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  # Static security scanner for Rails
  gem 'brakeman', require: false
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'listen', '~> 3.3'
  gem 'rack-mini-profiler', '~> 2.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  # Preview emails in browser instead of sending them
  gem 'letter_opener'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'jsbundling-rails'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

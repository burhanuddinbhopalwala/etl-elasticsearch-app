# Gemfile
source 'https://rubygems.org'

gem 'activerecord'
gem 'elasticsearch'
gem 'require_all'
gem 'ruby-kafka'
# gem "pg", "~> 0.18.4"
# gem "mysql2", "~> 0.5.3"
gem 'logger', '~> 1.4.2'
gem 'standalone_migrations'

# development and test groups are not bundled as part of the deployment
group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'execjs', require: false
  gem 'pre-commit', require: false
  gem 'rubocop', '~> 1.4', require: false
end

group :test do
  gem 'rspec' # rspec test group only or we get the "irb: warn: can't alias context from irb_context warning" when starting jets console
end

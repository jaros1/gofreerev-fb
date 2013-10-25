source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.0'

# Gem for FB APP integration
gem 'koala', '1.7.0rc1'

# Use sqlite3 as the database for Active Record
gem 'sqlite3'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

gem "jquery-ui-rails", "~> 4.0.4"

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano', group: :development

# Use debugger
# gem 'debugger', group: [:development, :test]

# rb-readline not needed. Problems with 0.4.2 and 0.5.0.pre.1 gems was fixed with:
# http://askubuntu.com/questions/261914/install-ruby-2-0-with-openssl-and-readline-support
# gem 'rb-readline', '~> 0.4.2'
# gem 'rb-readline', '~> 0.5.0.pre.1'
# Problems with both rb-readline gems.

# https://github.com/jmazzi/crypt_keeper
# crypt_keeper-0.13.1: problem with encrypted fields in after_insert/update callbacks
# solved in 0.14.0.pre version
# gem install crypt_keeper -v 0.14.0.pre
gem 'crypt_keeper', '~> 0.14.0.pre'

# https://github.com/bcardarella/client_side_validations
# client side validations is not ready for rails 4.0
# gem 'client_side_validations', '4-0-beta'

# https://github.com/hexorx/countries
gem 'countries'

# https://rubygems.org/gems/currencies
gem 'currencies'

# https://rubygems.org/gems/money
gem 'money'

# https://github.com/RubyMoney/google_currency
# just in case if we need to exchange currencies
gem 'google_currency'

# https://github.com/svenfuchs/rails-i18n
# rails-i18n (4.0.0.pre) - example yml files for many languages
gem 'rails-i18n', '~> 4.0.0.pre'

gem 'debugger'

group :test do
  if RUBY_PLATFORM =~ /(win32|w32)/
    gem "win32console", '1.3.0'
  end
  gem "minitest"
  gem "minitest-reporters", '>= 0.5.0'
end

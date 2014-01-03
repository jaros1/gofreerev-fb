source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.0'

# use omniauth for authorization / login
gem 'omniauth'
# See list of supported stategies: https://github.com/intridea/omniauth/wiki/List-of-Strategies
gem 'omniauth-facebook'      # https://github.com/mkdynamic/omniauth-facebook
gem "omniauth-google-oauth2" # https://github.com/zquestz/omniauth-google-oauth2
gem 'omniauth-linkedin'      # https://github.com/skorks/omniauth-linkedin
gem 'omniauth-twitter'       # https://github.com/arunagw/omniauth-twitter

# one gem for each omniauth-xxxx gem - post login API requests - get friends, update status, send notifications etc
gem 'koala', '1.7.0rc1' # facebook API calls - https://github.com/arsduo/koala/wiki/Koala-on-Rails
gem 'google-api-client' # google+ API calls  - https://github.com/google/google-api-ruby-client & https://developers.google.com/api-client-library/ruby/
gem 'linkedin'          # LinkedIn API calls - https://rubygems.org/gems/linkedin
gem 'twitter'           # twitter API calls  - http://sferik.github.io/twitter/

# Use sqlite3 as the database for Active Record
gem 'sqlite3'
gem 'mysql2'

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
# Turbolink - fix jquery document.ready - https://github.com/kossnocorp/jquery.turbolinks
gem 'jquery-turbolinks'

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
group :development do
  gem "capistrano-rails"
end


# Use debugger
# gem 'debugger', group: [:development, :test]

# https://github.com/jmazzi/crypt_keeper
# crypt_keeper-0.13.1: problem with encrypted fields in after_insert/update callbacks. solved in 0.14.0.pre version
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
# gem 'google_currency', '~> 2.3.0'
gem 'google_currency', '~> 3.0.0'

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

gem 'open4'

gem 'fastimage'

# https://github.com/svenfuchs/routing-filter
gem 'routing-filter', '~> 0.4.0.pre'

# https://github.com/kares/session_off
gem 'session_off'
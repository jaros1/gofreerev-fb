source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.0'

# use omniauth for authorization / login
gem 'omniauth'

# See list of supported stategies: https://github.com/intridea/omniauth/wiki/List-of-Strategies
# login providers must have support for friends list (mutual friends, follows or followed by)
# one gem for each omniauth-xxxx gem - post login API requests - get friends, update status, send notifications etc

# find provider api reference: search for <provider> api reference endpoints rest
# find ruby gem: search for ruby <provider> gem

# 1) facebook:
# register : https://developers.facebook.com/ - select Apps in menu
# reference: https://developers.facebook.com/docs/graph-api/reference/
gem 'omniauth-facebook' # https://github.com/mkdynamic/omniauth-facebook
gem 'koala', '1.9.0' # facebook API calls - https://github.com/arsduo/koala/wiki/Koala-on-Rails

# 2) flickr
# register : http://www.flickr.com/services/apps/create/
# reference: http://www.flickr.com/services/api/
gem 'omniauth-flickr' # https://github.com/timbreitkreutz/omniauth-flickr
gem 'flickraw' # flickr API calls - https://github.com/hanklords/flickraw

# 3) foursquare
# register : https://foursquare.com/developers/apps
# reference: https://developer.foursquare.com/docs/
gem 'omniauth-foursquare' # https://github.com/arunagw/omniauth-foursquare
gem 'foursquare2' # foursquare API calls - https://github.com/mattmueller/foursquare2

# 4) google+
# register : https://cloud.google.com/console/project - select API Project - APIs & auth - Credentials
# reference: https://developers.google.com/+/api/latest/ &
gem "omniauth-google-oauth2" # https://github.com/zquestz/omniauth-google-oauth2
gem 'google-api-client' # google+ API calls - https://github.com/google/google-api-ruby-client & https://developers.google.com/api-client-library/ruby/

# 5) instagram
# register : http://instagram.com/developer/clients/manage/#
# reference: http://instagram.com/developer/endpoints/#
gem "omniauth-instagram" # https://github.com/ropiku/omniauth-instagram
gem 'instagram', '0.10.0' # Instagram API calls  - https://github.com/Instagram/instagram-ruby-gem

# 6) linkedin
# register : https://www.linkedin.com/secure/developer
# reference: https://developer.linkedin.com/apis
gem 'omniauth-linkedin' # https://github.com/skorks/omniauth-linkedin
gem 'linkedin', '0.4.4' # LinkedIn API calls   - https://rubygems.org/gems/linkedin

# 7) twitter
# register : https://apps.twitter.com/
# reference: https://dev.twitter.com/docs/api/1.1
gem 'omniauth-twitter' # https://github.com/arunagw/omniauth-twitter
gem 'twitter' # twitter API calls    - http://sferik.github.io/twitter/

# 8) VKontakte
# register : http://vk.com/dev
# reference: https://vk.com/pages?oid=-17680044&p=API_Method_Description
# permissions: http://vk.com/dev/permissions
# - 4 Photos is required for photo upload (.photos.getWallUploadServer)
gem 'omniauth-vkontakte' # https://github.com/mamantoha/omniauth-vkontakte
# 3 possible gems:
# a) https://github.com/galetahub/vkontakte - last update 2 years ago - 31 commits - 3 contributors
# has a user.photos.getWallUploadServer method that is first step in uploading photo to user profile/wall
# has not a post or upload method that is second step in uploading photo to user profile/wall
gem 'vkontakte'
# b) https://github.com/zinenko/vk-ruby - last update 9 months ago - 146 commits - 4 contributors
# gem 'yajl-ruby' # used in vk-ruby 0.7.4 - note that there also is a vk-ruby 0.9.4 that could by used
# gem 'vk-ruby' # https://github.com/zinenko/vk-ruby - last update 9 months ago - 146 commits - 4 contributors
# c) https://github.com/7even/vkontakte_api - up-to-date - 185 commits - 7 contributors
# gem 'vkontakte_api' # https://github.com/7even/vkontakte_api - up-to-date - 185 commits - 7 contributors
gem 'rest_client' # for post multipart in vkontakte_api uploads

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
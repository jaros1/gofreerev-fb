
# name and URL's for this project
APP_NAME = 'Gofreerev'
FACEBOOK_APP_URL = 'http://apps.facebook.com/gofreerev'
SITE_URL = 'http://localhost/'

# where can you find source for this open source project?
CVS_NAME = 'GitHub'
CVS_URL = 'https://github.com/jaros1/gofreerev-fb'

# OS environment constants for encryption
# You can use ruby script /lib/generate_keys to generate keys and this ruby array constant
# note that ENCRYPT_KEYS[1] == ENV["GOFREEREV_#{railsenv}_KEY_2"] etc
railsenv = case Rails.env when 'development' then 'DEV' when 'test' then 'TEST' when 'production' then 'PROD' end
encrypt_keys = []
1.upto(50).each do |keyno|
  encrypt_keys << ENV["GOFREEREV_#{railsenv}_KEY_#{keyno}"]
end
ENCRYPT_KEYS = encrypt_keys

# negative interest
NEGATIVE_INTEREST_PER_DAY = 0.02 # 0.02 % per day <=> 0.6 % per month <=> 7.0 % per year

# calculate interest per month and per year
#PRICE_FACTOR_PER_DAY = 1 - NEGATIVE_INTEREST_PER_DAY / 100
#PRICE_FACTOR_PER_MONTH = PRICE_FACTOR_PER_DAY**(365 / 12)
#PRICE_FACTOR_PER_YEAR = PRICE_FACTOR_PER_DAY**365
#NEGATIVE_INTEREST_PER_MONTH = (1 - PRICE_FACTOR_PER_MONTH) * 100
#NEGATIVE_INTEREST_PER_YEAR = (1 - PRICE_FACTOR_PER_YEAR) * 100

# user.balance is an hash with user balance for each currency. Key BALANCE_KEY is used for total balance in BASE_CURRENCY.
BALANCE_KEY = 'BALANCE'

# interest calculation setup. Uses different negative interest for positive (5 %) and negative amounts (10 %)
# year 1: a = 100, b = -100. year 2: a =  95, b =  -90.
# in that way we get negative interest and an increasing supply of free money between 0 and 5 % per year
NEG_INT_NEG_BALANCE_PER_YEAR = 10.0 # 10 % negative interest per year for positive balance (gifts given to others)
NEG_INT_POS_BALANCE_PER_YEAR =  5.0 # 5 % negative interest per year for negative balance (gifts received from others)
FACTOR_NEG_BALANCE_PER_YEAR = 1.0 - NEG_INT_NEG_BALANCE_PER_YEAR / 100.0 # 0.90 = 100 - 10 %
FACTOR_POS_BALANCE_PER_YEAR = 1.0 - NEG_INT_POS_BALANCE_PER_YEAR / 100.0 # 0.95 = 100 - 5 %
FACTOR_NEG_BALANCE_PER_DAY = (Math::E) ** (Math.log(FACTOR_NEG_BALANCE_PER_YEAR,Math::E) / 365) # 0.9997113827109777
FACTOR_POS_BALANCE_PER_DAY = (Math::E) ** (Math.log(FACTOR_POS_BALANCE_PER_YEAR,Math::E) / 365) # 0.9998594803001535

BASE_CURRENCY = 'USD' # store exchange rates and internal balances in this currency
BASE_COUNTRY = 'us' # default country if user country is unknown.
BASE_LANGUAGE = 'en' # default language if user language is unknown

DEBUG_AJAX = true # default false - set to true to get more ajax debug information - JS alerts, extra log messages etc

# max one show-more-rows ajax request every 3 seconds.
# See shared/show_more_rows and get_next_set_of_rows_error? and get_next_set_of_rows methods in application controller
# todo: minor problem with sync. of 3 seconds delay in JS and rails.
GET_MORE_ROWS_INTERVAL = 3.0

# show cookie note in top of page (EU cookie law / Directive on Privacy and Electronic Communications)
# keep time and/or text small - cookie note is intruding and irritating - nil to disable/hide cookie note
# texts are set in locale keys application.layouts.cookie_note_*
# user can accept, reject or ignore cookie note
SHOW_COOKIE_NOTE = 30 # nil or number of seconds to display cookie note in header
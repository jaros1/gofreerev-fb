
# name and URL's for this project
APP_NAME = 'Gofreerev'
FB_APP_URL = 'http://apps.facebook.com/gofreerev'
SITE_URL = 'http://localhost/'

# where can you find source for this open source project?
CVS_NAME = 'GitHub'
CVS_URL = 'https://github.com/jaros1/gofreerev-fb'

# some OS environment constants for encryption
# You can use ruby script /lib/generate_keys to generate keys and this ruby array constant
ENCRYPT_KEYS = [ ENV['GOFREEREV_KEY_1'], ENV['GOFREEREV_KEY_2'], ENV['GOFREEREV_KEY_3'],
                 ENV['GOFREEREV_KEY_4'], ENV['GOFREEREV_KEY_5'], ENV['GOFREEREV_KEY_6'],
                 ENV['GOFREEREV_KEY_7'], ENV['GOFREEREV_KEY_8'], ENV['GOFREEREV_KEY_9'],
                 ENV['GOFREEREV_KEY_10'], ENV['GOFREEREV_KEY_11'], ENV['GOFREEREV_KEY_12'],
                 ENV['GOFREEREV_KEY_13'], ENV['GOFREEREV_KEY_14'], ENV['GOFREEREV_KEY_15'],
                 ENV['GOFREEREV_KEY_16'], ENV['GOFREEREV_KEY_17'], ENV['GOFREEREV_KEY_18'],
                 ENV['GOFREEREV_KEY_19'], ENV['GOFREEREV_KEY_20'], ENV['GOFREEREV_KEY_21'],
                 ENV['GOFREEREV_KEY_22'], ENV['GOFREEREV_KEY_23'], ENV['GOFREEREV_KEY_24'],
                 ENV['GOFREEREV_KEY_25'], ENV['GOFREEREV_KEY_26'], ENV['GOFREEREV_KEY_27'],
                 ENV['GOFREEREV_KEY_28'], ENV['GOFREEREV_KEY_29'], ENV['GOFREEREV_KEY_30'],
                 ENV['GOFREEREV_KEY_31'], ENV['GOFREEREV_KEY_32'], ENV['GOFREEREV_KEY_33'],
                 ENV['GOFREEREV_KEY_34'], ENV['GOFREEREV_KEY_35'], ENV['GOFREEREV_KEY_36'],
                 ENV['GOFREEREV_KEY_37'], ENV['GOFREEREV_KEY_38'], ENV['GOFREEREV_KEY_39'],
                 ENV['GOFREEREV_KEY_40'], ENV['GOFREEREV_KEY_41'], ENV['GOFREEREV_KEY_42'],
                 ENV['GOFREEREV_KEY_43'], ENV['GOFREEREV_KEY_44'], ENV['GOFREEREV_KEY_45'],
                 ENV['GOFREEREV_KEY_46'], ENV['GOFREEREV_KEY_47'], ENV['GOFREEREV_KEY_48'],
                 ENV['GOFREEREV_KEY_49'], ENV['GOFREEREV_KEY_50'] ]


# negative interest
NEGATIVE_INTEREST_PER_DAY = 0.02 # 0.02 % per day <=> 0.6 % per month <=> 7.0 % per year

# calculate interest per month and per year
PRICE_FACTOR_PER_DAY = 1 - NEGATIVE_INTEREST_PER_DAY / 100
PRICE_FACTOR_PER_MONTH = PRICE_FACTOR_PER_DAY ** (365 / 12)
PRICE_FACTOR_PER_YEAR = PRICE_FACTOR_PER_DAY ** 365
NEGATIVE_INTEREST_PER_MONTH = (1 - PRICE_FACTOR_PER_MONTH) * 100
NEGATIVE_INTEREST_PER_YEAR = (1 - PRICE_FACTOR_PER_YEAR) * 100
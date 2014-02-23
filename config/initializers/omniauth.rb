# http://stackoverflow.com/questions/13112430/find-loaded-providers-for-omniauth
# add OmniAuth::Builder.providers method to return list of loaded providers
module OmniAuth

  class Builder < ::Rack::Builder
    def provider_patch(klass, *args, &block)
      @@providers ||= []
      @@providers << klass.to_s
      old_provider(klass, *args, &block)
    end
    alias old_provider provider
    alias provider provider_patch
    class << self
      def providers
        @@providers
      end
    end
  end
end # OmniAuth

# setup list of providers to be used for authorization. Must be login provider API with som kind of friend lists
# providers: https://github.com/intridea/omniauth/wiki/List-of-Strategies
# check list when adding a new omniauth provider:
#  1) add gem omniauth-<provider> (authorization ) and gem <provider> (client API operations) to GemFile.
#     that is normally two gems for each omniauth supported strategy (authorization and client API operations)
#  2) get API_ID and API_SECRET for new provider. Register and add environment variables with API_ID and API_SECRET.
#     environment variable names "GOFREEREV_<env>_APP_ID_<provider>" and "GOFREEREV_<env>_APP_SECRET_<provider>"
#     for example GOFREEREV_DEV_APP_ID_FACEBOOK and GOFREEREV_DEV_APP_SECRET_FACEBOOK for facebook / development
#  3) add provider in this file (9 API_... hash constants)
#  4) add provider to OmniAuth::Builder setup in this file. options are different for each provider
#  5) add any provider specific methods to OmniAuth::AuthHash. See config/initializers/omniauth_<provider>.rb.
#     check if auth_hash information is written correct to user record in auth/create
#  6) add init_api_client_<provider> method to app. controller
#     you must as minimum supply a gofreerev_get_friends instance method to new api_client
#     you must supply a gofreerev_upload instance method to api_client if api supports upload
#  7) add private post on task to UtilController.post_on_<provider> if wall posting is allowed for API
#  8) check API_POST_PERMITTED and API_MUTUAL_FRIENDS hashes for new provider (environment.rb)
#  9) search source for "API SETUP" and check if new provider should be added to existing case statements

# initialize API_ID and API_SECRET hashes to be used in authorization and API requests
api_id = {}
api_secret = {}
%w(facebook flickr foursquare google_oauth2 instagram linkedin twitter vkontakte).each do |provider|
  rails_env = case Rails.env when "development" then "DEV" when "test" then "TEST" when "production" then "PROD" end
  # get api_id for provider
  name = "gofreerev_#{rails_env}_app_id_#{provider}".upcase
  api_id[provider] = ENV[name]
  puts "Warning: environment variable #{name} was not found" if api_id[provider].to_s == ""
  # get api_secret for provider
  name = "gofreerev_#{rails_env}_app_secret_#{provider}".upcase
  api_secret[provider] = ENV[name]
  puts "Warning: environment variable #{name} was not found" if api_secret[provider].to_s == ""
end
API_ID     = api_id.with_indifferent_access
API_SECRET = api_secret.with_indifferent_access

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook,      API_ID[:facebook],      API_SECRET[:facebook], :scope => "", :image_size => :normal, :info_fields => "name,permissions,friends,picture,timezone"
  provider :flickr,        API_ID[:flickr],        API_SECRET[:flickr], :scope => 'read'
  provider :foursquare,    API_ID[:foursquare],    API_SECRET[:foursquare]
  provider :google_oauth2, API_ID[:google_oauth2], API_SECRET[:google_oauth2], :scope => "plus.login userinfo.profile"
  provider :instagram,     API_ID[:instagram],     API_SECRET[:instagram]
  provider :linkedin,      API_ID[:linkedin],      API_SECRET[:linkedin], :scope => "r_basicprofile r_network", :fields => ['id', 'first-name', 'last-name', 'picture-url', 'public-profile-url', 'location']
  provider :twitter,       API_ID[:twitter],       API_SECRET[:twitter], { :image_size => 'bigger', :authorize_params => { :x_auth_access_type => 'write' } }
  provider :vkontakte,     API_ID[:vkontakte],     API_SECRET[:vkontakte], { :scope => 'friends,photos' }
end

# additional API setup

# visit or redirect to API
API_URL = {:facebook => "https://www.facebook.com",
           :flickr => 'https://www.flickr.com/',
           :foursquare => 'https://foursquare.com',
           :google_oauth2 => "https://plus.google.com/",
           :instagram => 'http://instagram.com/', # not secure!
           :linkedin => "https://www.linkedin.com/",
           :twitter => "https://twitter.com/",
           :vkontakte => 'https://vk.com/'}.with_indifferent_access

# callback url used in util controller and in API specific controllers (facebook, linkedin) - request extra privs.
API_CALLBACK_URL = {:facebook => "#{SITE_URL}facebook/",
                    :flickr => "#{SITE_URL}flickr/index",
                    :foursquare => '',
                    :google_oauth2 => '',
                    :instagram => '',
                    :linkedin => "#{SITE_URL}linkedin/index",
                    :twitter => '',
                    :vkontakte => ''}.with_indifferent_access

# default user permissions after login.
# facebook: koala me?fields=permissions request is used to check facebook permissions after login
# twitter: authorization with write access, but user must enable post on twitter before write permission is used
API_DEFAULT_PERMISSIONS = {:flickr => 'read',
                           :foursquare => 'read',
                           :google_oauth2 => 'read',
                           :instagram => 'read',
                           :linkedin => 'r_basicprofile,r_network',
                           :twitter => 'read',
                           :vkontakte => 'read'}.with_indifferent_access

# link to API app settings so that user easy can review and change permissions
API_APP_SETTING_URL = {:facebook => 'https://www.facebook.com/settings?tab=applications',
                       :flickr => 'https://www.flickr.com/account/sharing/',
                       :foursquare => 'https://foursquare.com/settings/connections',
                       :google_oauth2 => 'https://plus.google.com/apps',
                       :instagram => 'https://instagram.com/accounts/manage_access#',
                       :linkedin => 'https://www.linkedin.com/secure/settings?userAgree=&goback=.nas_*1_*1_*1',
                       :twitter => 'https://twitter.com/settings/applications',
                       :vkontakte => 'https://vk.com/settings'}.with_indifferent_access

# API name to be used in messages and mouse over texts
# text for "nil" API provider (not logged in or generic messages) /locales/xx.yml/shared/providers
API_DOWNCASE_NAME = {:facebook => 'facebook',
                     :flickr => 'flickr',
                     :foursquare => 'foursquare',
                     :google_oauth2 => 'google+',
                     :instagram => 'instagram',
                     :linkedin => 'linkedin',
                     :twitter => 'twitter',
                     :vkontakte => 'vkontakte'}.with_indifferent_access

# API name to be used in views and links
# text for "nil" API provider (not logged in or generic messages) /locales/xx.yml/shared/providers
API_CAMELIZE_NAME = {:facebook => 'Facebook',
                     :flickr => 'Flickr',
                     :foursquare => 'Foursquare',
                     :google_oauth2 => 'Google+',
                     :instagram => 'Instagram',
                     :linkedin => 'LinkedIn',
                     :twitter => 'Twitter',
                     :vkontakte => 'VKontakte'}.with_indifferent_access

# API profile pictures: :api or :local. Default is :api <=> Profile pictures are not downloaded from provider
API_PROFILE_PICTURE_STORE = {}.with_indifferent_access

# gift pictures: nil (no picture/readonly api), :api (use api picture url) or :local (keep local copy of picture)
# gooogle+ must be :local or nil (readonly api)
# instagram must be :local or nil (readonly api)
# linkedin must be :local or nil (only picture url is uploaded to linkedin)
# fallback must be :local or nil (use :local to enable local gift picture store as a fallback/last option)
API_GIFT_PICTURE_STORE = {:fallback => nil,
                          :facebook => :api,
                          :flickr => :api,
                          :foursquare => nil, # todo: post allowed, but users do not have a wall like the other api's
                          :google_oauth2 => nil, # google+ is a readonly API
                          :instagram => nil, # instagram is a readonly API
                          :linkedin => :local, # images are not uploaded to LinkedIn and must be stored on gofreerev server
                          :twitter => :api,
                          :vkontakte => :api}.with_indifferent_access

# text to picture options - PhantomJS (http://phantomjs.org/) is required for this - use empty hash {} if disabled.
# note that PhantomJs required relative much memory and time to run and should maybe not run on a small plug computer
# values:
# - nil: disabled / not allowed. use this option if phantomJS is not installed and for readonly API's
# - integer: use if description.length > integer and no picture attachment in post
# - 0: always, for example flickr (no picture attachment in post)
# - 70: use text to picture if description > 70 characters. twitter. (no picture attachment in post)
# - :append: append text to bottom of picture, for example flickr.
# text to image convert is done in 3:4 format if possible (w:800, h:1066)
API_TEXT_TO_PICTURE = {:facebook => nil,
                       :flickr => 0,
                       :foursquare => nil,
                       :google_oauth2 => nil,
                       :instagram => nil,
                       :linkedin => nil,
                       :twitter => 70,
                       :vkontakte => 0}.with_indifferent_access

# open graph values (http://ogp.me/) recommended max length for meta-tags used in deep links
# default values: 70 characters for title and 200 characters for description
API_OG_TITLE_SIZE = {:facebook => 94, # http://wptest.means.us.com/online-meta-tag-length-checker/
                     :flickr => 60, # todo: check
                     :foursquare => 60, # todo: check
                     :google_oauth2 => 63,
                     :instagram => 60, # todo: check
                     :linkedin => 60,
                     :twitter => 70,
                     :vkontakte => 60}.with_indifferent_access
API_OG_DESC_SIZE = {:facebook => 255, # http://www.joshspeters.com/how-to-optimize-the-ogdescription-tag-for-search-and-social
                    :flickr => 155, # todo: check
                    :foursquare => 155, # todo: check
                    :google_oauth2 => 155,
                    :instagram => 155, # todo: check
                    :linkedin => 220, # max 220 in util.post_on_linkedin ( up to 245 characters allowed in og:description meta-tag )
                    :twitter => 200,
                    :vkontakte => 155}.with_indifferent_access
API_OG_DEF_IMAGE = {:facebook => "#{SITE_URL}images/sacred-economics.jpg",
                    :flickr => "#{SITE_URL}images/sacred-economics.jpg",
                    :foursquare => "#{SITE_URL}images/sacred-economics.jpg",
                    :google_oauth2 => "#{SITE_URL}images/sacred-economics.jpg",
                    :instagram => "#{SITE_URL}images/sacred-economics.jpg",
                    :linkedin => "#{SITE_URL}images/sacred-economics-linkedin.jpg", # 180 x 110 best for linkedin
                    :twitter => "#{SITE_URL}images/sacred-economics.jpg",
                    :vkontakte => "#{SITE_URL}images/sacred-economics.jpg"}.with_indifferent_access

# for twitter:site card meta-tag - The Twitter username of the owner of this card's domain. - only twitter
API_OWNER = { :twitter => ENV['GOFREEREV_APP_OWNER_TWITTER'] }.with_indifferent_access

# extract basic information from auth_hash (provider, uid, user_name, token, language)
# provider specific versions can be implemented with get_<method>_<provider>.
# See omniauth_linkedin.rb for an example.
class OmniAuth::AuthHash
  def get_provider
    provider = self[:provider]
    provider = nil if provider.to_s == ""
    provider
  end
  def get_uid
    provider = get_provider()
    method = "get_uid_#{provider}"
    return eval(method) if respond_to? method.to_sym
    uid = self[:uid]
    uid = nil if uid.to_s == ""
    uid
  end
  def get_user_name
    provider = get_provider()
    method = "get_user_name_#{provider}"
    return eval(method) if respond_to? method.to_sym
    name = self[:info][:name] if self[:info]
    name = nil if name.to_s == ""
    nickname =self[:info][:nickname] if self[:info]
    nickname = nil if nickname.to_s == ""
    email = self[:info][:email] if self[:info]
    email = nil if email.to_s == ""
    email = email.split(/[\.|@]/).first(2).join(' ').camelcase if email
    name || nickname || email    
  end
  def get_token
    provider = get_provider()
    method = "get_token_#{provider}"
    return eval(method) if respond_to? method.to_sym
    token = self[:credentials][:token] if self[:credentials]
    token = nil if token.to_s == ""
    token
  end
  def get_country
    provider = get_provider()
    method = "get_country_#{provider}"
    return eval(method) if respond_to? method.to_sym
    nil
  end
  def get_language
    provider = get_provider()
    method = "get_language_#{provider}"
    return eval(method) if respond_to? method.to_sym
    locale = self[:extra][:raw_info][:locale] if self[:extra] and self[:extra][:raw_info]
    locale = "#{locale}".first(2)
    locale = BASE_LANGUAGE if locale.to_s == ""
    locale
  end
  def get_image
    provider = get_provider()
    method = "get_image_#{provider}"
    return eval(method) if respond_to? method.to_sym
    image = self[:info][:image] if self[:info]
    image = nil if image.to_s == ""
    image = nil if image and image !~ /^https?:/
    image
  end
  def get_profile_url
    provider = get_provider()
    method = "get_profile_url_#{provider}"
    return eval(method) if respond_to? method.to_sym
    profile_url = self[:extra][:raw_info][:link] if self[:extra] and self[:extra][:raw_info]
    profile_url
  end
end # OmniAuth::AuthHash

OmniAuth.config.on_failure = AuthController.action(:oauth_failure)
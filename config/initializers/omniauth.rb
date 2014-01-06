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
#  5) add any provider specific methods to OmniAuth::AuthHash. See config/initializers/omniauth_<provider>.rb
#  6) add private post login task to UtilController.post_login_<provider> if any (get friends, permissions etc)
#  7) add private post on task to UtilController.post_on_<provider> if wall posting is allowed for API
#  8) check API_POST_PERMITTED and API_MUTUAL_FRIENDS hashes for new provider (environment.rb)

# initialize API_ID and API_SECRET hashes to be used in authorization and API requests
api_id = {}
api_secret = {}
%w(facebook google_oauth2 linkedin twitter).each do |provider|
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
  provider :google_oauth2, API_ID[:google_oauth2], API_SECRET[:google_oauth2], :scope => "plus.login userinfo.profile"
  provider :linkedin,      API_ID[:linkedin],      API_SECRET[:linkedin], :scope => "r_basicprofile r_network", :fields => ['id', 'first-name', 'last-name', 'picture-url', 'public-profile-url', 'location']
  provider :twitter,       API_ID[:twitter],       API_SECRET[:twitter]
end

# additional API setup

# visit or redirect to API
API_URL = {:facebook => "https://www.facebook.com",
           :google_oauth2 => "https://plus.google.com/",
           :linkedin => "https://www.linkedin.com/",
           :twitter => "https://twitter.com/"}.with_indifferent_access

# callback url used in util controller and in API specific controllers (facebook, linkedin)
API_CALLBACK_URL = {:facebook => "#{SITE_URL}facebook/",
                    :google_oauth2 => '',
                    :linkedin => "#{SITE_URL}linkedin/index",
                    :twitter => ''}.with_indifferent_access

# API name to be used in messages and mouse over texts
API_DOWNCASE_NAME = {:facebook => 'facebook',
                     :google_oauth2 => 'google+',
                     :linkedin => 'linkedin',
                     :twitter => 'twitter'}.with_indifferent_access

# API name to be used in views and links
API_CAMELIZE_NAME = {:facebook => 'Facebook',
                     :google_oauth2 => 'Google+',
                     :linkedin => 'LinkedIn',
                     :twitter => 'Twitter'}.with_indifferent_access

# API profile pictures: :api or :local. Default is :api <=> Profile pictures are not downloaded from provider
API_PROFILE_PICTURE_STORE = {}.with_indifferent_access

# gift pictures: nil (no picture/readonly api), :api (use api picture url) or :local (keep local copy of picture)
# gooogle+ must be :local or nil (readonly api)
# linkedin must be :local or nil (only picture url is uploaded to linkedin)
API_GIFT_PICTURE_STORE = {:facebook => :api,
                          :google_oauth2 => nil, # images not uploaded to google+ - google+ is a readonly API
                          :linkedin => :local, # images are not uploaded to LinkedIn
                          :twitter => :api}.with_indifferent_access

# open graph values (http://ogp.me/) recommended max length for meta-tags used in deep links
# default values: 70 characters for title and 200 characters for description
API_OG_TITLE_SIZE = {:facebook => 94, # http://wptest.means.us.com/online-meta-tag-length-checker/
                     :google_oauth2 => 63,
                     :linkedin => 55,
                     :twitter => 70}.with_indifferent_access
API_OG_DESC_SIZE = {:facebook => 200, # http://www.joshspeters.com/how-to-optimize-the-ogdescription-tag-for-search-and-social
                    :google_oauth2 => 155,
                    :linkedin => 200,
                    :twitter => 200}.with_indifferent_access
API_OG_DEF_IMAGE = {:facedbook => "#{SITE_URL}images/sacred-economics.jpg",
                    :google_oauth2 => "#{SITE_URL}images/sacred-economics.jpg",
                    :linkedin => "#{SITE_URL}images/sacred-economics-linkedin.jpg", # 180 x 110 best for linkedin
                    :twitter => "#{SITE_URL}images/sacred-economics.jpg"}

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
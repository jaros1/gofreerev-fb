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
#  1) add gem omniauth-<provider> (authorizatrion )and gem <provider> (client API operations) to GemFile.
#     that is normally two gems for each omniauth supported strategy (authorization and client API operations)
#  2) add provider in this file (6 API_... hash constants)
#  3) add provider to OmniAuth::Builder setup in this file. options are different for each provider
#  4) add any provider specific methods to OmniAuth::AuthHash. See config/initializers/omniauth_<provider>.rb
#  5) add provider to /config/locals - shared/providers/* with downcase and camelize names used in messages/views and urls for redirect
#  6) add private post login task to UtilController.post_login_<provider> if any (get friends, permissions etc)
#  7) add private post on task to UtilController.post_on_<provider> if wall posting is allowed for API
#  8) check API_POST_PERMITTED and API_MUTUAL_FRIENDS hashes for new provider (environment.rb)
API_ID            = {:facebook      => ENV['GOFREEREV_FB_APP_ID'],
                     :google_oauth2 => ENV['GOFREEREV_GP_APP_ID'],
                     :linkedin      => ENV['GOFREEREV_LI_APP_ID'],
                     :twitter       => ENV['GOFREEREV_TW_APP_ID']}.with_indifferent_access
API_SECRET        = {:facebook      => ENV['GOFREEREV_FB_APP_SECRET'],
                     :google_oauth2 => ENV['GOFREEREV_GP_APP_SECRET'],
                     :linkedin      => ENV['GOFREEREV_LI_APP_SECRET'],
                     :twitter       => ENV['GOFREEREV_TW_APP_SECRET']}.with_indifferent_access
API_URL           = {:facebook      => "https://www.facebook.com",
                     :google_oauth2 => "https://plus.google.com/",
                     :linkedin      => "https://www.linkedin.com/",
                     :twitter       => "https://twitter.com/"}.with_indifferent_access
API_CALLBACK_URL  = {:facebook      => "#{SITE_URL}facebook/",
                     :google_oauth2 => '',
                     :linkedin      => "#{SITE_URL}linkedin/index",
                     :twitter       => ''}.with_indifferent_access

# open graph (http://ogp.me/) recommended max length for meta-tags used in deep links
# default values: 70 characters for title and 200 characters for description
API_OG_TITLE_SIZE = {:facebook      => 94, # http://wptest.means.us.com/online-meta-tag-length-checker/
                     :google_oauth2 => 63,
                     :linkedin      => 55,
                     :twitter       => 70}.with_indifferent_access
API_OG_DESC_SIZE  = {:facebook      => 200, # http://www.joshspeters.com/how-to-optimize-the-ogdescription-tag-for-search-and-social
                     :google_oauth2 => 155,
                     :linkedin      => 200,
                     :twitter       => 200}.with_indifferent_access
API_OG_DEF_IMAGE  = {:facedbook     => "#{SITE_URL}images/sacred-economics.jpg",
                     :google_oauth2 => "#{SITE_URL}images/sacred-economics.jpg",
                     :linkedin      => "#{SITE_URL}images/sacred-economics-linkedin.jpg", # 180 x 110 best for linkedin
                     :twitter       => "#{SITE_URL}images/sacred-economics.jpg"}

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook,      API_ID[:facebook],      API_SECRET[:facebook], :scope => "", :image_size => :normal, :info_fields => "name,permissions,friends,picture,timezone"
  provider :google_oauth2, API_ID[:google_oauth2], API_SECRET[:google_oauth2], :scope => "plus.login userinfo.profile"
  provider :linkedin,      API_ID[:linkedin],      API_SECRET[:linkedin], :scope => "r_basicprofile r_network", :fields => ['id', 'first-name', 'last-name', 'picture-url', 'public-profile-url', 'location']
  provider :twitter,       API_ID[:twitter],       API_SECRET[:twitter]
end

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
end # OmniAuth::AuthHash

OmniAuth.config.on_failure = AuthController.action(:oauth_failure)
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

# setup list of providers to be used for authorization. Should be API with "friend-liste"
# providers: https://github.com/intridea/omniauth/wiki/List-of-Strategies
# tasks when adding a new provider:
#  1) add provider to GemFile
#  2) add provider here
#  3) add any provider specific methods to OmniAuth::AuthHash. See config/initializers/omniauth_<provider>.rb
#  4) add provider to locals
#     a) shared/providers with lowercase provider name used in messages
#  5) add post_login task to UtilController.post_login_<provider> if any (get friend lists, permissions etc)
#  6) todo: add methods to post status and pictures on provider wall if any. See xxxxxxx
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook,      ENV['GOFREEREV_FB_APP_ID'], ENV['GOFREEREV_FB_APP_SECRET'], :scope => "", :image_size => :normal, :info_fields => "name,permissions,friends,picture,timezone"
  provider :google_oauth2, ENV['GOFREEREV_GP_APP_ID'], ENV['GOFREEREV_GP_APP_SECRET'], :scope => "plus.login userinfo.profile"
  provider :linkedin,      ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET'], :scope => "r_basicprofile", :fields => ['id', 'first-name', 'last-name', 'picture-url', 'public-profile-url', 'location']
  provider :twitter,       ENV['GOFREEREV_TW_APP_ID'], ENV['GOFREEREV_TW_APP_SECRET']
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


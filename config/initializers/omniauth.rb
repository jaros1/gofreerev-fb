# setup list of providers to be used for authorization. Should be API with "friend-liste"
# providers: https://github.com/intridea/omniauth/wiki/List-of-Strategies
# add providers to GemFile and locales
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook,      ENV['GOFREEREV_FB_APP_ID'], ENV['GOFREEREV_FB_APP_SECRET'], :scope => "", :image_size => :normal, :info_fields => "name,permissions,friends,picture,timezone"
  provider :google_oauth2, ENV['GOFREEREV_GP_APP_ID'], ENV['GOFREEREV_GP_APP_SECRET'], :name => "google"
  provider :linkedin,      ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET'], :scope => "r_basicprofile", :fields => ['id', 'first-name', 'last-name', 'picture-url', 'public-profile-url']
  provider :twitter,       ENV['GOFREEREV_TW_APP_ID'], ENV['GOFREEREV_TW_APP_SECRET']
end

# extract basic information from auth_hash.
class OmniAuth::AuthHash
  def get_provider
    provider = self[:provider]
    provider = nil if provider.to_s == ""
    provider
  end
  def get_uid
    uid = self[:uid]
    uid = nil if uid.to_s == ""
    uid
  end
  def get_user_name
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
    token = self[:credentials][:token] if self[:credentials]
    token = nil if token.to_s == ""
    token
  end
  def get_locale
    case get_provider
      when 'facebook'
        locale = self[:extra][:raw_info][:locale] if self[:extra] and self[:extra][:raw_info]
      when 'google'
        locale = self[:extra][:raw_info][:locale] if self[:extra] and self[:extra][:raw_info]
      else nil # = en
    end # case
    locale = "#{locale}".first(2)
    locale = 'en' if locale.to_s == ""
    locale
  end
  def get_image
    image = self[:info][:image] if self[:info]
    image = nil if image.to_s == ""
    image = nil if image and image !~ /^https?:/
    image
  end
end

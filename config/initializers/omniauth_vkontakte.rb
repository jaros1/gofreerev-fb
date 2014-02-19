Vkontakte.setup do |config|
  config.app_id = API_ID[:vkontakte]
  config.app_secret = API_SECRET[:vkontakte]
  config.format = :json
  config.debug = false
  # config.logger = File.open(Rails.root.join('log', 'vkontakte.log'), "a")
end

class OmniAuth::AuthHash
  def get_profile_url_vkontakte
    profile_url = self[:info][:urls][:Vkontakte] if self[:info] and self[:info][:urls]
    profile_url
  end
  def get_image_vkontakte
    image = self[:extra][:raw_info][:photo_100] if self[:extra] and self[:extra][:raw_info]
    image
  end
end
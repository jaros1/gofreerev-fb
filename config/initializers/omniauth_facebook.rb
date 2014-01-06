class OmniAuth::AuthHash
  def get_image_facebook
    # profile image from omniauth login is not used (wrong picture dimensions)
    # profile image from koala request in post_login_facebook is used
    nil
  end
  def get_country_facebook
    locale = self[:extra][:raw_info][:locale] if self[:extra] and self[:extra][:raw_info]
    locale = "#{locale}".last(2)
    locale = BASE_COUNTRY if locale.to_s == ""
    locale
  end
end
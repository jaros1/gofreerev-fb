class OmniAuth::AuthHash
  def get_country_facebook
    locale = self[:extra][:raw_info][:locale] if self[:extra] and self[:extra][:raw_info]
    locale = "#{locale}".last(2)
    locale = 'us' if locale.to_s == ""
    locale
  end
end
class OmniAuth::AuthHash
  # no language code from linkedin - convert country code to language
  def get_country_linkedin
    code = self[:extra][:raw_info][:location][:country][:code] if self[:extra] and self[:extra][:raw_info] and self[:extra][:raw_info][:location] and self[:extra][:raw_info][:location][:country]
    code = BASE_COUNTRY if code.to_s == ""
    code
  end # get_language_linkedin
  def get_language_linkedin
    code = get_country()
    c = Country[code]
    return BASE_LANGUAGE unless c
    language = c.languages.first
    language = BASE_LANGUAGE unless language
    language
  end # get_language_linkedin
  # return array with token AND secret for linkedin - token AND secret are required for linkedin gem
  def get_token_linkedin
    token = self[:credentials][:token] if self[:credentials]
    secret = self[:credentials][:secret] if self[:credentials]
    return nil unless token.to_s != "" and secret.to_s != ""
    [ token, secret]
  end # get_token_linkedin
end
class OmniAuth::AuthHash
  def get_user_name
    return self.info.nickname if self.info.nickname.to_s != ""
    self.info.name
  end
  def get_profile_url_flickr
    self.info.urls.Profile._content if self.info and self.info.urls and self.info.urls.Profile
  end
  # return array with token AND secret for flickr - token AND secret are required for flickraw gem (oauth 1)
  def get_token_flickr
    token = self.credentials.token if self.credentials
    secret = self.credentials.secret if self.credentials
    return nil unless token.to_s != "" and secret.to_s != ""
    [ token, secret]
  end
end
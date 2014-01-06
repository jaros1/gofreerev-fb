class OmniAuth::AuthHash
  def get_image_google_oauth2
    # full size profile picture is received from google+ login
    # add ?sz=50 to url received from in omniauth login
    # http://stackoverflow.com/questions/9128700/getting-google-profile-picture-url-with-user-id
    image = self[:info][:image] if self[:info]
    image = nil if image.to_s == ""
    image = nil if image and image !~ /^https?:/
    return nil unless image
    "#{image}?sz=50" # profile picture size 50 x 50
  end
end
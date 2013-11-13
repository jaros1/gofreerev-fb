Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, ENV['GOFREEREV_FB_APP_ID'], ENV['GOFREEREV_FB_APP_SECRET']
  provider :gplus,    ENV['GOFREEREV_GP_APP_ID'], ENV['GOFREEREV_GP_APP_SECRET'], :name => "google"
  provider :linkedin, ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET']
  provider :twitter,  ENV['GOFREEREV_TW_APP_ID'], ENV['GOFREEREV_TW_APP_SECRET']
end
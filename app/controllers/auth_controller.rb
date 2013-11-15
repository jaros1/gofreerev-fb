class AuthController < ApplicationController

  def index
    @providers = OmniAuth::Builder.providers
    # find logged in providers - userid and token
    user_ids = session[:user_ids] || []
    tokens = session[:tokens] || {}
    @logged_in_providers = user_ids.collect { |user_id| user_id.split('/').last }.find_all { |provider| tokens[provider].to_s != "" }
  end

  def create
    @auth_hash = auth_hash
    user = User.find_or_create_from_auth_hash(auth_hash)
    language_code = auth_hash.get_language
    country = auth_hash.get_country
    if !country
      # provider dod not return country code. Try to get country code from language code
      countries = []
      Country.countries.each do |a|
        country_code = a[1]
        country = Country[country_code]
        countries << country_code if country.languages.index('da')
      end
      if countries.size == 1
        country = countries.first
      else
        country = 'us'
      end
    end
    puts "auth.create: language = #{language_code}"
    puts "auth.create: country = #{country}"
  end # create

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

end

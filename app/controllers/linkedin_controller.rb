require 'linkedin'

class LinkedinController < ApplicationController

  # reauthorize linkedin user with scope r_basicprofile r_network rw_nus
  # that is - allow gofreerev to post on linkedin wall if user allows it
  # http://developer.linkedin.com/documents/authentication
  # Parameters: {"code"=>"AQS__ODMSihloboRVKmw5YL1YaSkq8JhWimzySl9Unf3FEF78pJbg853M2-guvrb09dSsgEPSr2j0qDyLmQu3QuGWVUx1JggD7yo3wyNddHbx0lap38", "state"=>"t7McTKIOSodWjxvVFyKdSKwYAv1PEt-rw_nus"}
  # Parameters: {"oauth_token"=>"75--62450be1-6396-45a9-b26f-050a2b471a9d", "oauth_verifier"=>"15521"}
  def index

    client = session[:linkedin_oauth]
    x = client.authorize_from_request(client.request_token.token, client.request_token.secret, params[:oauth_verifier])
    puts "x = #{x}"
    tokens = session[:tokens]
    tokens["linkedin"] = x
    session[:tokens] = tokens
    session.delete(:linkedin_oauth)

  end

end

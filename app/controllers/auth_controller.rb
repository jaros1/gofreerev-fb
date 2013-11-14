class AuthController < ApplicationController

  def create
    @auth_hash = auth_hash
    user = User.find_or_create_from_auth_hash(auth_hash)
  end # create

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

end

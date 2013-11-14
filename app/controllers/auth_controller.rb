class AuthController < ApplicationController
  def create
    puts "auth_hash = #{auth_hash}"
    render :text => request.env['omniauth.auth'].inspect
  end # create


  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end

require 'linkedin'

class LinkedinController < ApplicationController

  # reauthorize linkedin user with scope r_basicprofile r_network rw_nus
  # that is - allow gofreerev to post on linkedin wall if user wants it
  # http://developer.linkedin.com/documents/authentication
  # http://railscarma.com/blog/rails-3/how-to-use-linkedin-api-in-rails-applications/
  # signatures:
  # 1) callback with rw_nus:
  #    Parameters: {"oauth_token"=>"75--62450be1-6396-45a9-b26f-050a2b471a9d", "oauth_verifier"=>"15521"}
  def index
    # linkedin oauth client was saved in util.post_on_linkedin after "(403): Access to posting shares denied" error
    client = get_linkedin_client
    x = client.authorize_from_request(client.request_token.token, client.request_token.secret, params[:oauth_verifier])
    puts "x = #{x} (#{x.class})"
    if x.class == Array and x.length == 2 and x[0].class == String and x[1].class == String and x[0] != "" and x[1] != ''
      puts "login ok. Get name, .... from linkedin"
      # get basic user information from linkedin before new login with write permission to linkedin wall
      client = LinkedIn::Client.new ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET']
      client.authorize_from_access x[0], x[1] # token and secret
      res1 = client.profile(:fields => %w(id,first-name,last-name,picture-url))
      # new login with write permission to linkedin wall
      res2 = login :provider => 'linkedin',
                  :token => x,
                  :uid => res1.id,
                  :name => "#{res1.first_name} #{res1.last_name}",
                  :image => res1.picture_url,
                  :country => nil,
                  :language => nil
      puts "res2 = #{res2}"
      if !res2
        # login ok
        flash[:notice] = t ".ok_rw_nus", :appname => APP_NAME
        redirect_to :controller => :gifts
      else
        # login failed
        key, options = res2
        begin
          flash[:notice] = t key, options
        rescue Exception => e
          puts "invalid response from login. Must be nil or a valid input to translate. Response: #{res2}"
          flash[:notice] = t '.find_or_create_from_auth_hash', :response => res2, :exception => e.message.to_s
        end
        redirect_to :controller => :auth
      end

    else
      puts "login not ok."
    end


  end

end

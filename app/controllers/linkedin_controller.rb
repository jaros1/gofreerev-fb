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
    puts2log  "x = #{x} (#{x.class})"
    if x.class == Array and x.length == 2 and x[0].class == String and x[1].class == String and x[0] != "" and x[1] != ''
      puts2log  "login ok. Get name, .... from linkedin"
      # get basic user information from linkedin before 2. login with write permission (rw_nus) to linkedin wall
      client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
      client.authorize_from_access x[0], x[1] # token and secret
      res1 = client.profile(:fields => %w(id,first-name,last-name,picture-url,public-profile-url))
      puts2log "res1.public_profile_url = #{res1.public_profile_url}"
      # index: res1.public_profile_url = http://www.linkedin.com/pub/jan-test-account-roslind/87/b08/27a
      # new login with write permission to linkedin wall
      res2 = login :provider => provider,
                  :token => x,
                  :uid => res1.id,
                  :name => "#{res1.first_name} #{res1.last_name}",
                  :image => res1.picture_url,
                  :country => nil,
                  :language => nil,
                  :profile_url => res1.public_profile_url
      puts2log  "res2 = #{res2}"
      if !res2
        # login ok with extra rw_nus priv
        user_id = "#{res1.id}/#{provider}"
        user = User.find_by_user_id(user_id)
        user.permissions = "r_basicprofile,r_network,rw_nus"
        user.save!
        flash[:notice] = t ".ok_rw_nus", :appname => APP_NAME
        redirect_to :controller => :gifts
      else
        # login failed
        key, options = res2
        begin
          flash[:notice] = t key, options
        rescue Exception => e
          puts2log  "invalid response from login. Must be nil or a valid input to translate. Response: #{res2}"
          flash[:notice] = t '.find_or_create_from_auth_hash', :response => res2, :exception => e.message.to_s
        end
        redirect_to :controller => :auth
      end

    else
      puts2log  "login not ok."
    end

  end # index


  private
  def provider
    "linkedin"
  end

end

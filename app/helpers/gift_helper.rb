# encoding: utf-8
module GiftHelper

  # link to request for status_update priv. (facebook)
  def auth_post_gift_url
    unless @user
      puts 'auth_post_gift_url: @user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - request for status_update priv
        oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, 'http://localhost/gifts/')
        state = session[:state] = String.generate_random_string(30)
        url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => state)
        puts "auth_post_gift_url: url2 = #{url}"
        return url
      else
        ''
    end
  end # auth_post_gift_url

  # link to request for status_update priv. (facebook)
  def auth_read_stream_url
    unless @user
      puts 'auth_read_stream_url: @user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - request for status_update priv
        oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, 'http://localhost/gifts/')
        state = session[:state] = String.generate_random_string(30)
        url = oauth.url_for_oauth_code(:permissions => 'read_stream', :state => state)
        puts "auth_read_stream_url: url2 = #{url}"
        return url
      else
        ''
    end
  end # auth_read_stream_url

end

# dump unexpected facebook/koala exceptions to log for easier debugging
class Koala::Facebook::ClientError
  def puts_exception (prefix=nil)
    puts "#{prefix}Koala::Facebook::ClientError"
    puts "#{prefix}fb_error_type    = #{fb_error_type} (#{fb_error_type.class})"
    puts "#{prefix}fb_error_code    = #{fb_error_code} (#{fb_error_code.class})"
    puts "#{prefix}fb_error_subcode = #{fb_error_subcode} (#{fb_error_subcode.class})"
    puts "#{prefix}fb_error_message = #{fb_error_message} (#{fb_error_message.class})"
    puts "#{prefix}http_status      = #{http_status} (#{http_status.class})"
    puts "#{prefix}response_body    = #{response_body}"
  end
end

class Koala::Facebook::ServerError
  def puts_exception (prefix=nil)
    puts "#{prefix}Koala::Facebook::ServerError"
    puts "#{prefix}fb_error_type    = #{fb_error_type} (#{fb_error_type.class})"
    puts "#{prefix}fb_error_code    = #{fb_error_code} (#{fb_error_code.class})"
    puts "#{prefix}fb_error_subcode = #{fb_error_subcode} (#{fb_error_subcode.class})"
    puts "#{prefix}fb_error_message = #{fb_error_message} (#{fb_error_message.class})"
    puts "#{prefix}http_status      = #{http_status} (#{http_status.class})"
    puts "#{prefix}response_body    = #{response_body}"
  end
end
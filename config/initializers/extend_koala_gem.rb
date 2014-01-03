# dump unexpected facebook/koala exceptions to log for easier debugging
class Koala::Facebook::ClientError
  def puts_exception (prefix=nil)
    logger.debug2  "#{prefix}Koala::Facebook::ClientError"
    logger.debug2  "#{prefix}fb_error_type    = #{fb_error_type} (#{fb_error_type.class})"
    logger.debug2  "#{prefix}fb_error_code    = #{fb_error_code} (#{fb_error_code.class})"
    logger.debug2  "#{prefix}fb_error_subcode = #{fb_error_subcode} (#{fb_error_subcode.class})"
    logger.debug2  "#{prefix}fb_error_message = #{fb_error_message} (#{fb_error_message.class})"
    logger.debug2  "#{prefix}http_status      = #{http_status} (#{http_status.class})"
    logger.debug2  "#{prefix}response_body    = #{response_body}"
  end
  #def logger.debug2  (text)
  #  logger.debug "#{caller_locations(1,1)[0].label}: #{text}"
  #end
end

class Koala::Facebook::ServerError
  def puts_exception (prefix=nil)
    logger.debug2  "#{prefix}Koala::Facebook::ServerError"
    logger.debug2  "#{prefix}fb_error_type    = #{fb_error_type} (#{fb_error_type.class})"
    logger.debug2  "#{prefix}fb_error_code    = #{fb_error_code} (#{fb_error_code.class})"
    logger.debug2  "#{prefix}fb_error_subcode = #{fb_error_subcode} (#{fb_error_subcode.class})"
    logger.debug2  "#{prefix}fb_error_message = #{fb_error_message} (#{fb_error_message.class})"
    logger.debug2  "#{prefix}http_status      = #{http_status} (#{http_status.class})"
    logger.debug2  "#{prefix}response_body    = #{response_body}"
  end
  #def logger.debug2  (text)
  #  logger.debug "#{caller_locations(1,1)[0].label}: #{text}"
  #end
end
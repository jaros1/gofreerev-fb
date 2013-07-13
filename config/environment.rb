# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Extend String
class String
  def self.generate_random_string (lng)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(lng) { |i| newpass << chars[rand(chars.size-1)] }
    newpass
  end # generate_random_string
end

# Initialize the Rails application.
GofreerevFb::Application.initialize!


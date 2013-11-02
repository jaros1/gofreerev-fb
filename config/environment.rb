# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Extend String
class String
  # random string - for keys, state etc
  def self.generate_random_string (lng)
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    newpass = ''
    1.upto(lng) { newpass << chars[rand(chars.size-1)] }
    newpass
  end # generate_random_string
  # used in views with language texts that can be String or arrays of String
  def each
    yield self
  end
end

# Implement find_usertype. Only relevant for Hash, but must exists as dummy methods in String and Array
# usertype is first two characters in user_id. That is FB, GP etc
# used in views to allow different texts in views for different login API's
# Hash: returns hash[usertype], hash[hash.keys.first] or []
class String
  def find_usertype(usertype)
    self
  end
end
class Array
  def find_usertype (usertype)
    self
  end
end
class Hash
  def find_usertype (usertype)
    return self[nil] if usertype == nil and self.has_key?(nil)
    for i in 1 .. 3 do loop
      key = case i
              when 1 then usertype
              when 2 then usertype.downcase
              when 3 then usertype.upcase
            end
      return self[key] if self.has_key?(key)
      key = case key.class.name
              when 'String' then key.to_sym ;
              when 'Symbol' then key.to_s
              else key
            end
      return self[key] if self.has_key?(key)
    end unless usertype == nil
    key = self.keys.first
    return [] unless key
    self[key]
  end # find_usertype (usertype)
end # find_usertype

# used in last_money_bank_request sequence
class Time
  def self.current_hour_no
    (Time.new.to_i/60-23000000).to_i
  end
end

# Initialize the Rails application.
GofreerevFb::Application.initialize!

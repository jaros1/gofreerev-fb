#
# This script can be used to generate encryption keys.
# Save your secret keys in a save location on the server and keep backups.
# Keys must be constant and can not be changed if they are used in the database.
# Run this script once at project start and never again (unless your keys has been exposed).
# You must empty the database for data and starting from scratch if the keys are lost
# Do not store the keys in clear text in rails source.
#

# comment the next line if you wish to run this script
exit

# number of keys and key length
PREFIX = 'GOFREEREV_KEY_' # Please change
NO_KEYS = 50
KEY_LNG = 140
RUBY_MAX_LINE_SIZE = 100 # For ruby array constant ENCRYPT_KEYS


# change if you wish other character set og other random generator.
def generate_random_string (lng)
  chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
  newpass = ""
  1.upto(lng) { |i| newpass << chars[rand(chars.size-1)] }
  newpass
end # generate_random_string

# generate keys - save in ruby array
keys = []
1.upto(NO_KEYS) { |i| keys[i] = generate_random_string(KEY_LNG) }

# output bash script
puts ""
puts "# you could store your secret keys in linux/bash:"
1.upto(NO_KEYS) do |i|
  puts "#{PREFIX}#{i}=#{keys[i]}"
  puts "export #{PREFIX}#{i}"
end

# todo: output keys in other formats, linux shell, windows dos etc

# output rails constraint to be inserted in /config/initializers/constraints.rb
puts ""
puts "insert this ruby constant in /config/initializers/constraints.rb"
line = 'ENCRYPT_KEYS = [ '
1.upto(NO_KEYS) do |i|
  next_item = "ENV['#{PREFIX}#{i}']" + (i==50 ? ' ]' : ', ')
  if (line+next_item).size > RUBY_MAX_LINE_SIZE
    puts line
    line = '                 '
  end
  line = line + next_item
end
puts line

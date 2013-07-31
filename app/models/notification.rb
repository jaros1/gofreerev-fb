class Notification < ActiveRecord::Base

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :noti_t_key, :noti_t_options, :encryptor => :aes, :key => ENCRYPT_KEYS[18]

  
  ##############
  # attributes #
  ##############

  # 1) noti_id - required - not encrypted - readonly
  validates_presence_of :noti_id
  validates_uniqueness_of :noti_id
  attr_readonly :noti_id
  before_validation(on: :create) do
    self.noti_id = self.new_encrypt_pk unless self.noti_id
  end
  def noti_id=(new_noti_id)
    return self['noti_id'] if self['noti_id']
    self['noti_id'] = new_noti_id
  end


  # 2) to_user_id - required - FK - not encrypted - readonly
  validates_presence_of :to_user_id
  attr_readonly :to_user_id

  
  # 3) from_user_id - required - FK - not encrypted - readonly
  validates_presence_of :from_user_id
  attr_readonly


  # 4) internal - required - Y/N - not encrypted
  validates_presence_of :internal
  validates_inclusion_of :internal, :in => %w(Y N)
  attr_readonly


  # 5) noti_t_key - key for translate - required - String in model - encrypted text in db
  validates_presence_of :noti_t_key
  attr_readonly :noti_t_key
  def noti_t_key
    return nil unless (extended_noti_t_key = read_attribute(:noti_t_key))
    encrypt_remove_pre_and_postfix(extended_noti_t_key, 'noti_t_key', 19)
  end
  def noti_t_key=(new_noti_t_key)
    if new_noti_t_key
      check_type('noti_t_key', new_noti_t_key, 'String')
      write_attribute :noti_t_key, encrypt_add_pre_and_postfix(new_noti_t_key, 'noti_t_key', 19)
    else
      write_attribute :noti_t_key, nil
    end
  end
  alias_method :noti_t_key_before_type_cast, :noti_t_key
 
  
  # 6) noti_t_options - required - Hash in Model - encrypted text in db
  # validates_presence_of :noti_t_options # does not work for some reason!
  attr_readonly :noti_t_options
  def noti_t_options
    return nil unless (temp_extended_noti_t_options = read_attribute(:noti_t_options))
    puts "get temp_extended_noti_t_options = #{temp_extended_noti_t_options} (#{temp_extended_noti_t_options.class.name})"
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_noti_t_options, 'noti_t_options', 20)
  end # noti_t_options
  def noti_t_options=(new_noti_t_options)
    if new_noti_t_options
      check_type('noti_t_options', new_noti_t_options, 'Hash')
      temp_extended_noti_t_options = encrypt_add_pre_and_postfix(new_noti_t_options.to_yaml , 'noti_t_options', 20)
      puts "set temp_extended_noti_t_options = #{temp_extended_noti_t_options} (#{temp_extended_noti_t_options.class.name})"
      write_attribute :noti_t_options, temp_extended_noti_t_options
    else
      puts "set temp_extended_noti_t_options = nil"
      write_attribute :noti_t_options, nil
    end
  end # noti_t_options=
  alias_method :noti_t_options_before_type_cast, :noti_t_options
  

  # 7) noti_read - required - Y/N String in model - not encrypted
  validates_presence_of :noti_read
  validates_inclusion_of :noti_read, :in => %w(Y N)


  ##################
  # helper methods #
  ##################


  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
  # overwrite non model specific methods defined in /config/initializers/active_record_extensions.rb
  protected
  def encrypt_pk
    self.noti_id
  end
  def encrypt_pk=(new_encrypt_pk_value)
    self.noti_id = new_encrypt_pk_value
  end
  def new_encrypt_pk
    loop do
      temp_noti_id = String.generate_random_string(20)
      return temp_noti_id unless Notification.find_by_noti_id(temp_noti_id)
    end
  end

end

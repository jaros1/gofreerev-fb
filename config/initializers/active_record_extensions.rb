# https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
# this extension to use different encryption for each attribute and each row
module ActiveRecordExtensions
  # these 3 methods must be replaces by model specific implementations
  protected
  def encrypt_pk
    self.gift_id
  end
  def encrypt_pk=(new_encrypt_pk_value)
    self.gift_id = new_encrypt_pk_value
  end
  def new_encrypt_pk
    temp_gift_id = nil
    loop do
      temp_gift_id = String.generate_random_string(20)
      return temp_gift_id unless Gift.find_by_gift_id(temp_gift_id)
    end
  end

  # general methods for attribute encryption
  # encrypt_add_pre_and_postfix and encrypt_remote_pre_and_postfix to de used in get/set attribute methods
  protected
  def encrypt_rand_seed (attributename, secret_key_no)
    self.encrypt_pk = self.new_encrypt_pk unless self.encrypt_pk
    hex = Digest::MD5.hexdigest(gift_id + ENCRYPT_KEYS[secret_key_no] + attributename)
    hex.to_i(16)
  end # rand_seed

  def encrypt_prefix (r, attributename, secret_key_no)
    prefix_lng = r.rand(20)+1
    chars = ENCRYPT_KEYS[secret_key_no].split('')
    temp_prefix = ""
    1.upto(prefix_lng) { |i| temp_prefix << chars[r.rand(chars.size-1)] }
    temp_prefix
  end

  def encrypt_postfix (r, attributename, secret_key_no)
    postfix_lng = r.rand(20)+1
    chars = ENCRYPT_KEYS[secret_key_no].split('')
    temp_postfix = ""
    1.upto(postfix_lng) { |i| temp_postfix << chars[r.rand(chars.size-1)] }
    temp_postfix
  end

  def encrypt_add_pre_and_postfix(value, attributename, secret_key_no)
    r = Random.new encrypt_rand_seed(attributename, secret_key_no)
    "#{encrypt_prefix(r, attributename, secret_key_no)}#{value}#{encrypt_postfix(r, attributename, secret_key_no)}"
  end

  def encrypt_remove_pre_and_postfix(value, attributename, secret_key_no)
    r = Random.new encrypt_rand_seed(attributename, secret_key_no)
    prefix_lng = encrypt_prefix(r, attributename, secret_key_no).size
    postfix_lng = encrypt_postfix(r, attributename, secret_key_no).size
    value_lng = value.size
    from = prefix_lng
    to = value_lng - postfix_lng - 1
    value[from..to]
  end
end
class User < ActiveRecord::Base

=begin
  create_table "users", force: true do |t|
    t.string   "user_id",    limit: 20
    t.text     "user_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "currency"
    t.text     "balance"
    t.date     "balance_at"
  end
=end

  # attributes
  #   user_id    - Unique user-id - not encrypted - PK
  #                Format FB-<userid> = facebook user
  #                Format GP-<xxxxxx> = google+ user
  #   user_name  - encrypted
  #   currency   - encrypted
  #   balance    - encrypted - BigDecimal
  #   balance_at - date for last balance calculation
  #   created_at - timestamp - not encrypted
  #   updated_at - timestamp - not encrypted


  # https://github.com/jmazzi/crypt_keeper
  crypt_keeper :user_name, :currency, :balance, :encryptor => :aes, :key => ENCRYPT_KEYS[0]

  def self.facebook_user_prefix
    'FB-'
  end # facebook_user_prefix
  def self.google_plus_user_prefix
    'GP-'
  end # google_plus_user_prefix

  def facebook?
    return false unless user_id
    user_id.first(3) == User.facebook_user_prefix
  end # facebook
  def google_plus?
    return false unless user_id
    user_id.first(3) == User.google_plus_user_prefix
  end # facebook

  # add login api to user name
  def user_name_with_api
    api = case
            when facebook?
              ' (facebook)'
            when google_plus?
              ' (google+)'
            else nil
          end
    "#{user_name}#{api}"
  end # user_name_with_api

  def currency_with_text
    return nil unless currency
    m = Money::Currency.table.find { |a| a[0] == currency.downcase.to_sym }
    return nil unless m
    "#{m[1][:iso_code]} #{m[1][:name]}".first(25)
  end # currency_with_text

end # User

require 'test_helper'
include ActionView::Helpers

class NilClass
  def round (options)
    nil
  end
end

class UserTest < ActiveSupport::TestCase

  # use this interrupt if you want to stop after failed test ==>
  @@interrupt = false
  def after_teardown
    @@interrupt = true if !passed? # signal that test must interrupt after this failed test has finished
    super
  end
  def before_setup
    super
    raise Interrupt if @@interrupt # previous test has failed. Interrupt test
  end
  # use this interrupt if you want to stop after failed test <==

  def debug_user_balance
    true
  end # debug_notifications

  def assert_hash (text, expected, found)
    found.keys.each do |name|
      # puts "#{text}: #{name}. Expected #{expected[name]}. Found #{found[name]}"
      assert (expected[name].round(8) == found[name].round(8)), "#{text}: #{name} is invalid. Expected #{expected[name]}. Found #{found[name]}" if expected.has_key?(name)
    end
  end

  def assert_gift (gift, expected)
    found = { :new_price => gift.new_price,
              :negative_interest => gift.negative_interest,
              :social_dividend => gift.social_dividend,
              :balance_giver => gift.balance_giver,
              :balance_receiver => gift.balance_receiver }
    assert_hash 'gift', expected, found
  end # assert_user_balance

  def assert_balance (user, expected)
    found = { :balance => user.balance[BALANCE_KEY],
              :usd => user.balance['USD'],
              :dkk => user.balance['DKK'],
              :sek => user.balance['SEK'] }
    assert_hash user.short_user_name, expected, found
  end

  # alias for fixtures
  def charlie # default currency DKK
    users(:charlie)
  end
  def u1_sandra # default currency USD
    users(:sandra)
  end
  def u2_karen # default currency USD
    users(:karen)
  end
  def u3_david # default currency DKK
    users(:david)
  end
  def u4_dick # default currency DKK
    users(:dick)
  end

  def dkk_usd
    exchange_rates(:dkk_usd).exchange_rate
  end
  def dkk_sek
    exchange_rates(:dkk_sek).exchange_rate
  end
  def sek_dkk
    exchange_rates(:sek_dkk).exchange_rate
  end
  def sek_usd
    exchange_rates(:sek_usd).exchange_rate
  end
  def usd_dkk
    exchange_rates(:usd_dkk).exchange_rate
  end
  def usd_sek
    exchange_rates(:usd_sek).exchange_rate
  end

  #create_table "gifts", force: true do |t|
  #  t.string   "gift_id",                     limit: 20
  #  t.text     "description",                            null: false
  #  t.text     "currency",                               null: false
  #  t.text     "price"
  #  t.string   "user_id_giver",               limit: 20
  #  t.string   "user_id_receiver",            limit: 20
  #  t.text     "received_at"
  #  t.date     "new_price_at"
  #  t.text     "new_price"
  #  t.text     "negative_interest"
  #  t.text     "social_dividend"
  #  t.datetime "created_at"
  #  t.datetime "updated_at"
  #  t.text     "api_gift_id"
  #  t.string   "gifttype",                    limit: 1,  null: false
  #  t.text     "balance_giver"
  #  t.text     "balance_receiver"
  #  t.string   "picture",                     limit: 1
  #  t.text     "api_picture_url"
  #  t.text     "api_picture_url_updated_at"
  #  t.text     "api_picture_url_on_error_at"
  #  t.string   "deleted_at_api",              limit: 1
  #  t.integer  "status_update_at",                       null: false
  #  t.text     "balance_doc_giver"
  #  t.text     "balance_doc_receiver"
  #  t.text     "social_dividend_doc"
  #end
  def create_deal(giver, receiver, price, days_ago)
    g = Gift.new
    g.description = "From #{giver.short_user_name} to #{receiver.short_user_name}"
    g.currency = charlie.currency
    g.price = price.to_f
    g.user_id_giver = giver.user_id
    g.gifttype = 'G'
    g.picture = 'N'
    assert g.save
    g.user_id_receiver = receiver.user_id
    g.received_at = days_ago.days.ago(Time.now)
    assert g.save
    g.recalculate
    g.reload
  end # create_deal


  test "create_gift_today" do
    # simple: create gift today - 0 negative interest and 0 social dividend
    g1 = create_deal(charlie, u2_karen, 10.0, 0) # charlie 10.00 dkk today
    charlie.recalculate_balance
    u2_karen.recalculate_balance
    g1.reload
    assert_gift g1,
                :new_price => 10.0,
                :negative_interest => 0.0,
                :social_dividend => 0.0,
                :balance_giver => 10.0, # charlie dkk
                :balance_receiver => -1.77063 # karen usd
    assert_balance charlie,
                   :balance => 10.0, # dkk
                   :dkk => 10.0
    assert_balance u2_karen,
                   :balance => -1.77063, # usd = -10.0 dkk * 0.177063
                   :dkk => -10.0
  end # create_gift_today


  test "create_gift_100_days_ago" do
    g1 = create_deal(charlie, u2_karen, 10.0, 100) # charlie 10.00 dkk 100 days ago
    # new price after 100 days = 10.0 * 0.9998 ** 100 = 9.801967126499463 dkk
    # negative interest after 100 days = 10.0 - 9.801967126499463 = 0.19803287350053722 dkk
    # social dividend after 100 days = 0.19803287350053722 / 4 = 0.049508218375134305 dkk
    charlie.recalculate_balance
    u2_karen.recalculate_balance
    g1.reload
    assert_gift g1,
                :new_price => 9.801967126499463,
                :negative_interest => 0.19803287350053722,
                :social_dividend => 0.049508218375134305,
                :balance_giver => 9.801967126499463, # dkk
                :balance_receiver => -1.7355657053193743 # usd
    # balance giver (charlie/dkk) = 9.801967126499463 DKK
    # balance receiver (karen/usd) = -9.801967126499463 DKK * 0.177063 = -1.7355657053193743 USD
    assert_balance charlie,
                   :balance => 9.801967126499463, # dkk
                   :dkk => 9.801967126499463
    assert_balance u2_karen,
                   :balance => -1.7355657053193743, # usd
                   :dkk => -9.801967126499463
  end # create_gift_100_days_ago

  test "create_gift_100_days_ago_and_today" do
    g1 = create_deal(charlie, u2_karen, 10.0, 100) # charlie 10.00 dkk 100 days ago
    g2 = create_deal(charlie, u2_karen, 10.0, 0) # charlie 10.00 dkk today
    charlie.recalculate_balance
    u2_karen.recalculate_balance
    g1.reload
    g2.reload
    # g1:
  end # create_gift_100_days_ago_and_today

end

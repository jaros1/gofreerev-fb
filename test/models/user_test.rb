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


  def create_deal(giver, receiver, price, days_ago)
    g = Gift.new
    g.description = "From #{giver.short_user_name} to #{receiver.short_user_name}"
    g.currency = giver.currency
    g.price = price.to_f
    g.user_id_giver = giver.user_id
    g.gifttype = 'G'
    g.picture = 'N'
    assert g.save
    g.update_attributes! :user_id_receiver => receiver.user_id, :received_at => days_ago.days.ago(Time.now)
    g.recalculate
    g.reload
    assert (g.received_at.to_date == days_ago.days.ago(Date.today)), "create_deal: received_at is invalid. Expected #{days_ago.days.ago(Date.today)}. Found #{g.received_at.to_date}"
    g
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

  test "create_gift_100_and_0_days_ago" do
    g1 = create_deal(charlie, u2_karen, 10.0, 100) # charlie 10.00 dkk 100 days ago
    g2 = create_deal(charlie, u2_karen, 10.0, 0) # charlie 10.00 dkk today
    charlie.recalculate_balance
    u2_karen.recalculate_balance
    g1.reload
    g2.reload
    # g1: 100 days ago. Same check as in create_gift_100_days_ago
    assert_gift g1,
                :new_price => 9.801967126499463,
                :negative_interest => 0.19803287350053722,
                :social_dividend => 0.049508218375134305,
                :balance_giver => 9.801967126499463, # dkk
                :balance_receiver => -1.7355657053193743 # usd
    # g2: today. add/subtract 10.00 dkk to/from balance
    # balance giver = 9.801967126499463 + 10.00 = 19.801967126499463
    # balance receiver = -1.7355657053193743 usd - (10.00 dkk * 0.177063) = -3.5061957053193744 usd
    assert_gift g2,
                :new_price => 10.0,
                :negative_interest => 0.0,
                :social_dividend => 0.0,
                :balance_giver => 19.801967126499463, # charlie dkk
                :balance_receiver => -3.5061957053193744 # karen usd
    # check user balance
    assert_balance charlie,
                   :balance => 19.801967126499463, # dkk
                   :dkk => 19.801967126499463
    assert_balance u2_karen,
                   :balance => -3.5061957053193744, # usd
                   :dkk => -19.801967126499463
  end # create_gift_100_and_0_days_ago

  test "create_gift_100_and_20_days_ago" do
    g1 = create_deal(charlie, u2_karen, 10.0, 100) # charlie 10.00 dkk 100 days ago
    g2 = create_deal(charlie, u2_karen, 10.0, 20) # charlie 10.00 dkk 20 days ago
    charlie.recalculate_balance
    u2_karen.recalculate_balance
    g1.reload
    g2.reload
    # g1: 100 days ago. Same check as in create_gift_100_days_ago
    assert_gift g1,
                :new_price => 9.801967126499463,
                :negative_interest => 0.19803287350053722,
                :social_dividend => 0.049508218375134305,
                :balance_giver => 9.801967126499463, # dkk
                :balance_receiver => -1.7355657053193743 # usd
    # g2: 20 days ago.
    # new_price = 10.00 * 0.9998 ** 20 = 9.960075908877474 dkk
    # negative_interest = 10.00 - 9.960075908877474 = 0.039924091122525596 dkk
    # social_dividend = 0.039924091122525596 / 4 = 0.009981022780631399 dkk
    # balance_giver = 9.801967126499463 + 9.960075908877474 = 19.762043035376937
    # balance_receiver = -1.7355657053193743 usd - (9.960075908877474 dkk * 0.177063) = -1.7355657053193743 - 1.7635609206535723 usd = -3.4991266259729468 usd
    assert_gift g2,
                :new_price => 9.960075908877474,
                :negative_interest => 0.039924091122525596,
                :social_dividend => 0.009981022780631399,
                :balance_giver => 19.762043035376937, # charlie dkk
                :balance_receiver => -3.4991266259729468 # karen usd
    # check user balance
    assert_balance charlie,
                   :balance => 19.762043035376937, # dkk
                   :dkk => 19.762043035376937
    assert_balance u2_karen,
                   :balance => -3.4991266259729468, # usd
                   :dkk => -19.762043035376937
  end # create_gift_100_and_20_days_ago

  test "create_gift_100_50_and_20_days_ago" do
    # charlie => sandra 10.00 dkk 100 days ago
    old_no_gifts = Gift.where("received_at is not null").count
    g1 = create_deal(charlie, u1_sandra, 10.00, 100)
    g1.create_social_dividend
    new_no_gifts = Gift.where("received_at is not null").count
    assert new_no_gifts == old_no_gifts + 1 # no social dividend yet. first deal for both users
    # charlie => karen 10.00 dkk 50 days ago
    old_no_gifts = new_no_gifts
    g2 = create_deal(charlie, u2_karen, 10.00, 50)
    g2.create_social_dividend
    new_no_gifts = Gift.where("received_at is not null").count
    assert new_no_gifts == old_no_gifts + 1 # no social dividend yet. Karen is a new user
    # sandra => karen 10.00 USD 20 days ago
    old_no_gifts = new_no_gifts
    g3 = create_deal(u1_sandra, u2_karen, 10.00, 20)
    g3.create_social_dividend # social dividend between sandra and karen
    g3.reload
    new_no_gifts = Gift.where("received_at is not null").count
    assert new_no_gifts == old_no_gifts + 2 # social dividend created
    # sandra/karen social dividend
    g4 = Gift.last
    assert g4.gifttype == 'S'
    # recalculate/reload before asserts
    charlie.recalculate_balance
    g1.reload
    g2.reload
    g3.reload
    g4.reload
    charlie.reload
    u1_sandra.reload
    u2_karen.reload

    # g1: 100 days ago charlie => sandra. Same check as in create_gift_100_days_ago
    assert_gift g1,
                :new_price => 9.801967126499463, # dkk
                :negative_interest => 0.19803287350053722,
                :social_dividend => 0.049508218375134305,
                :balance_giver => 9.801967126499463, # dkk charlie
                :balance_receiver => -1.7355657053193743 # usd sandra

    # g2: 50 days ago (charlie => karen)
    # new_price = 10.00 * 0.9998 ** 50 = 9.90048843567804 dkk
    # negative_interest = 10.00 - 9.90048843567804 = 0.09951156432195951 dkk
    # social_dividend = 0.09951156432195951 / 4 = 0.024877891080489878 dkk
    # balance_giver = 9.801967126499463 + 9.90048843567804 = 19.702455562177505 dkk (charlie)
    # balance_receiver = - (9.90048843567804 dkk * 0.177063) = -1.753010183886461 usd (karen)
    assert_gift g2,
                :new_price => 9.90048843567804, # dkk
                :negative_interest => 0.09951156432195951,
                :social_dividend => 0.024877891080489878,
                :balance_giver => 19.702455562177505, # charlie dkk
                :balance_receiver => -1.753010183886461 # karen usd

    # g3: 20 days ago (sandra => karen)
    # new_price = 10 * 0.9998 ** 20 = 9.960075908877474 usd
    # negative_interest = 10 - 9.960075908877474 = 0.039924091122525596 usd
    # social_dividend = 0.039924091122525596 / 4 = 0.009981022780631399
    # balance_giver (sandra) = -1.7355657053193743 + 9.960075908877474 = 8.2245102035581 usd
    # balance_receiver (karen) = -1.753010183886461 - 9.960075908877474 = -11.713086092763936 usd
    assert_gift g3,
                :new_price => 9.960075908877474, # usd
                :negative_interest => 0.039924091122525596,
                :social_dividend => 0.009981022780631399,
                :balance_giver => 8.2245102035581, # sandra usd
                :balance_receiver => -11.713086092763936 # karen usd

    # g4: social dividend for g3: 20 days ago (sandra => karen)
    # sandra: one gift g1 with charlie 10.00 dkk 100 days ago
    #         g1 new price 20 days ago: 10.00 * 0.9998 ** 80 = 9.841257452428561 dkk
    #         g1 negative interest 20 days ago = 0.15874254757143902 dkk
    #         g1 social dividend = 0.15874254757143902 / 4 = 0.039685636892859755 dkk
    # karen:  one gift g2 with charlie 10.00 dkk 50 days ago
    #         g2 new price 20 days ago: 10.00 * 0.9998 ** 30 = 9.94017367563803 dkk
    #         g2 negative interest 20 days ago = 10.00 - 9.94017367563803 = 0.05982632436196944 dkk
    #         g2 social dividend 20 days ago = 0.05982632436196944 / 4 = 0.01495658109049236 dkk
    # difference: (0.039685636892859755 - 0.01495658109049236)/2).abs.round(2) = 0.01 dkk
    # g4 should transfer 0.01 dkk from sandra to karen
    assert g4.gifttype == 'S'
    assert g4.currency == 'DKK'
    assert g4.price == 0.01
    assert g4.user_id_giver == u1_sandra.user_id
    assert g4.user_id_receiver == u2_karen.user_id
    # balance giver sandra  :   8.2245102035581   - 0.01 * 0.177063 =  8.222739573558101 usd
    # balance receiver karen: -11.713086092763936 + 0.01 * 0.177063 = -11.711315462763936 usd
    assert_gift g4,
                :new_price => 0.01, # dkk
                :negative_interest => 0.00,
                :social_dividend => 0.01, # dkk
                :balance_giver => 8.222739573558101, # sandra usd
                :balance_receiver => -11.711315462763936 # karen usd

    # check user balance
    # charlie - 2 gifts - g1 10.00 dkk 100 days ago and g2 10.00 dkk 50 days ago
    #           g1 = 10.00 * 0.9998 ** 100 = 9.801967126499463 dkk
    #           g2 = 10.00 * 0.9998 ** 50 = 9.90048843567804 dkk
    #           9.801967126499463 + 9.90048843567804 = 19.702455562177505
    assert_balance charlie,
                   :balance => 19.702455562177505, # dkk
                   :dkk => 19.702455562177505
    # sandra - 3 gifts - g1 10.00 dkk 100 days ago, g3 10.00 usd 20 days ago, g4 social dividend 20 days ago
    #          g1 = -10.00 * 0.9998 ** 100 = -9.801967126499463 dkk = -1.7355657053193743 usd
    #          g3 =  10.00 * 0.9998 ** 20 = 9.960075908877474 usd
    #          g4 =  -0.01 dkk = -0.00177063 usd
    #          usd = g3 = 9.960075908877474
    #          dkk = g1 + g4 = -9.801967126499463 - 0.01 = -9.811967126499463
    #          balance = -1.7355657053193743 + 9.960075908877474 - 0.00177063 = 8.222739573558101
    assert_balance u1_sandra,
                   :balance => 8.222739573558101, # usd
                   :dkk => -9.811967126499463,
                   :usd => 9.960075908877474
    # karen - 3 gifts - g2 10.00 dkk 50 days ago, g3 10.00 usd 20 days ago and g4 social dividend 20 days ago
    #         g2 = -10.00 * 0.9998 ** 50 = -9.90048843567804 dkk = -1.753010183886461 usd
    #         g3 = -10.00 * 0.9998 ** 20 = -9.960075908877474 usd
    #         g4 = 0.01 dkk = 0.00177063 usd
    #         usd = g3 = -9.960075908877474 usd
    #         dkk = g2 + g4 = -9.90048843567804 + 0.01 = -9.89048843567804 dkk
    #         balance = -1.753010183886461 + -9.960075908877474 + 0.00177063 = -11.711315462763936
    assert_balance u2_karen,
                   :balance => -11.711315462763936, # usd
                   :dkk => -9.89048843567804,
                   :usd => -9.960075908877474
  end # create_gift_100_and_20_days_ago


end

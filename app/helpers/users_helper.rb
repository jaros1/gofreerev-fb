module UsersHelper

  # document user balance calculation in users/show page (mouse over for balance)
  def gift_balance_calculation_doc(gift, current_user)
    return nil if !gift.user_id_giver or !gift.user_id_receiver
    return nil if !gift.price or gift.price <= 0
    # format documentation for balance.
    # one format without currency and exchange rate if exchange rate == 1
    # one format with currency and exchange rate if exchange rate != 1
    # format: new balance yyy user currency = old balance xxx +- (price - negative interest) * exchange rate
    balance_doc = gift.balance_doc(current_user)
    return nil unless balance_doc
    exchange_rate1 = ExchangeRate.exchange(1.0, gift.currency, @user.currency, gift.received_at)
    exchange_rate2 = ExchangeRate.exchange(1.0, 'USD', @user.currency, gift.received_at)
    exchange_rate3 = ExchangeRate.exchange(1.0, 'USD', @user.currency, balance_doc[:previous_date])
    return nil unless exchange_rate1 and exchange_rate2 and exchange_rate3
    old_balance_hash = balance_doc[:previous_balance]
    old_balance = (old_balance_hash[BALANCE_KEY] * exchange_rate3).round(2)
    sign_negative_interest = old_balance >= 0 ? '-' : '+'
    # calculate exchange rate gains/losses
    # that is previous_balance + negative_interest in old and new exchange rates
    # calculation is done in current users actual currency
    previous_date = balance_doc[:previous_date]
    if gift.gifttype == 'G' and previous_date != gift.received_at.to_yyyymmdd
      old_exchange_rates = balance_doc[:previous_exchange_rates]
      new_exchange_rates = balance_doc[:exchange_rates]
      previous_date = balance_doc[:previous_date]
      previous_balance_neg_int_hash = balance_doc[:previous_balance_and_negative_interest]
      old_sum = 0.0
      new_sum = 0.0
      previous_balance_neg_int_hash.keys.each do |currency|
        puts "gift id = #{gift.id}, currency = #{currency}"
        old_sum += ExchangeRate.exchange(previous_balance_neg_int_hash[currency] / old_exchange_rates[currency], 'USD', current_user.currency, previous_date)
        new_sum += ExchangeRate.exchange(previous_balance_neg_int_hash[currency] / new_exchange_rates[currency], 'USD', current_user.currency, gift.received_at)
      end
      gain_loss = new_sum - old_sum
      puts "exchange rate gains/losses. gift id #{gift.id}, gain/loss #{gain_loss}"
    else
      gain_loss = 0.0
    end
    # 5 translation key elements: balance_title [, exchange_rate ] [, negative_interest] [, gain/loss], [, social_dividend]
    # 14 translation keys: balance_title, balance_title_gain, balance_title_loss, balance_title_exchange_rate, balance_title_exchange_rate_gain,
    #                      balance_title_exchange_rate_loss, balance_title_negative_interest, balance_title_negative_interest_gain,
    #                      balance_title_negative_interest_loss, balance_title_exchange_rate_negative_interest,
    #                      balance_title_exchange_rate_negative_interest_gain, balance_title_exchange_rate_negative_interest_loss,
    #                      balance_title_social_dividend and balance_title_exchange_rate_social_dividend:
    translate_key = ['.balance_title']
    translate_key << 'exchange_rate' if exchange_rate1.round(3) != 1.000
    negative_interest = gift.balance_doc(current_user)[:negative_interest][BALANCE_KEY] || 0.00
    negative_interest = negative_interest * exchange_rate3
    translate_key << 'negative_interest' if negative_interest.round(2) != 0.00
    if gain_loss.round(2) != 0.00
      if gain_loss > 0.00
        translate_key << 'gain'
        sign_gain_loss = '+'
      else
        translate_key << 'loss'
        sign_gain_loss = '-'
        gain_loss = -gain_loss
      end
    end
    translate_key << "social_dividend" if gift.gifttype == 'S'
    translate_key = translate_key.join('_')
    # todo: add exchange_rate_difference hash
    number_of_days = (gift.received_at.to_date - Date.parse(previous_date)).to_i
    my_t translate_key, # calculation: new_balance = old_balance + price * exchange_rate + negative_interest + currency_gain_loss
                        :new_balance => format_price(gift.balance(current_user, @user)),
                        :old_balance => format_price(old_balance),
                        :sign_price => balance_doc[:sign],
                        :price => format_price(gift.price),
                        :exchange_rate => exchange_rate1.round(6),
                        :sign_negative_interest => sign_negative_interest,
                        :negative_interest => format_price(negative_interest),
                        :sign_currency_gain_loss => sign_gain_loss,
                        :currency_gain_loss => format_price(gain_loss),
                        :new_currency => @user.currency,
                        :old_currency => gift.currency,
                        :number_of_days => number_of_days
  end # gift_balance_calculation_doc

end

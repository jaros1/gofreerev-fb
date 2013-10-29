module UsersHelper

  # document user balance calculation in users/show page (mouse over for balance)
  def gift_balance_calculation_doc(gift, current_user)
    return nil if !gift.user_id_giver or !gift.user_id_receiver
    return nil if !gift.price or gift.price <= 0
    # format documentation for balance.
    # one format without currency and exchange rate if exchange rate == 1
    # one format with currency and exchange rate if exchange rate != 1
    # format: new balance yyy user currency = old balance xxx +- (price - negative interest) * exhange rate
    balance_doc = gift.balance_doc(current_user)
    return nil unless balance_doc
    exchange_rate1 = balance_doc[:exchange_rate] # exchange rate from gift currency to current user currency
    exchange_rate2 = ExchangeRate.exchange(1.0, current_user.currency, @user.currency)
    exchange_rate = exchange_rate1 * exchange_rate2
    return nil if !exchange_rate1
    # 4 keys: balance_title, balance_title_exchange_rate, balance_title_negative_interest, balance_title_exchange_rate_negative_interest
    translate_key = ['.balance_title']
    translate_key << 'exchange_rate' if exchange_rate.round(3) != 1.000
    negative_interest = gift.negative_interest
    translate_key << 'negative_interest' if negative_interest.round(2) != 0.00
    translate_key << "social_dividend" if gift.gifttype == 'S'
    translate_key = translate_key.join('_')
    old_balance = balance_doc[:previous_balance]
    old_balance = (old_balance * exchange_rate2).round(2)
    my_t translate_key, :old_balance => format_price(old_balance),
                        :new_balance => format_price(gift.balance(current_user, @user)),
                        :old_price => format_price(gift.price),
                        :negative_interest => format_price(negative_interest),
                        :new_price => format_price(gift.new_price),
                        :sign => balance_doc[:sign],
                        :exchange_rate => exchange_rate.round(6),
                        :new_currency => @user.currency,
                        :old_currency => gift.currency
  end # gift_balance_calculation_doc

end

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
    # that is previous_balance + negative_interest in old (date=previous_date) and new (date=received_at) exchange rates
    # calculation is done in current users actual currency
    # note that gains/losses changes if current user selects to see balance in an other currency
    previous_date = balance_doc[:previous_date]
    if previous_date != gift.received_at.to_yyyymmdd
      old_exchange_rates = balance_doc[:previous_exchange_rates]
      new_exchange_rates = balance_doc[:exchange_rates]
      previous_date = balance_doc[:previous_date]
      previous_balance_hash = balance_doc[:previous_balance]
      negative_interest_hash = balance_doc[:negative_interest]
      old_sum = 0.0
      new_sum = 0.0
      previous_balance_hash.keys.each do |currency|
        next if currency == BALANCE_KEY
        puts "gift id = #{gift.id}, currency = #{currency}"
        amount = previous_balance_hash[currency] + negative_interest_hash[currency]
        old_sum += ExchangeRate.exchange(amount / old_exchange_rates[currency], 'USD', current_user.currency, previous_date)
        new_sum += ExchangeRate.exchange(amount / new_exchange_rates[currency], 'USD', current_user.currency, gift.received_at)
      end
      gain_loss = new_sum - old_sum
      puts "exchange rate gains/losses. gift id #{gift.id}, gain/loss #{gain_loss}"
    else
      gain_loss = 0.0
    end
    # 4 translation key elements: balance_title [, exchange_rate ] [, negative_interest] [, gain/loss] - [, xxx] are optional elements
    # 12 translation keys: balance_title, balance_title_gain, balance_title_loss, balance_title_exchange_rate, balance_title_exchange_rate_gain,
    #                      balance_title_exchange_rate_loss, balance_title_negative_interest, balance_title_negative_interest_gain,
    #                      balance_title_negative_interest_loss, balance_title_exchange_rate_negative_interest,
    #                      balance_title_exchange_rate_negative_interest_gain and balance_title_exchange_rate_negative_interest_loss
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
    translate_key = translate_key.join('_')
    # todo: add more documentation for gain/loss calculation?
    number_of_days = (gift.received_at.to_date - Date.parse(previous_date)).to_i
    t translate_key, # calculation: new_balance = old_balance + price * exchange_rate + negative_interest + currency_gain_loss
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

  # helpers for friends filter and invide friends link
  # shown in one or 2 lines depending on screen width
  def friends_filter_text
    t '.friends_filter_prompt', :appname => APP_NAME, :appname_camelized => APP_NAME.camelize
  end # app_friends_tex

  def app_friends_link (friends_filter)
    if friends_filter == true
      t('.app_friends_link_text')
    else
      link_to t('.app_friends_link_text'), users_path(:friends => true)
    end
  end # show_app_friends_link

  def not_app_friends_link (friends_filter)
    if friends_filter == false
      t('.not_app_friends_link_text')
    else
      link_to t('.not_app_friends_link_text'), users_path(:friends => false)
    end
  end # not_app_friends_link

  def app_friends_friends_link (friends_filter)
    if friends_filter == nil
      t('.all_app_users_link_text')
    else
      link_to t('.all_app_users_link_text'), users_path
    end
  end # all_friends_friends_link

  def invite_api_friends_text
    t '.invite_api_friends_link_prompt2', :apiname => @user.api_name_without_brackets, :apiname_camelized => @user.api_name_without_brackets.camelize
  end # invite_friends_text

  def invite_api_friends_link
    link_to t('.invite_api_friends_link_text2', :apiname => @user.api_name_without_brackets), invite_friends_url, :title => t('.invite_api_friends_link_title2', :appname => APP_NAME, :apiname => @user.api_name_without_brackets)
  end

  # user_nav_link is used in users/show nav links - up to 9 links in up to 3 sections
  # nav links is displayed in 1, 2 or 3 lines in users/show page depending on screen width
  # prefix must match prefix for entries in users/user_nav_links in locals
  def user_nav_link (options)
    # puts "users_helper.user_nav_link: input options = #{options}"
    prefix = options.delete(:prefix)
    symbol = case prefix
               when 'tabs' then :tab
               when 'deal_status' then :status
               when 'deal_direction' then :direction
               else
                 puts "error in users/_user_nav_links. user_nav_link must be called with prefix tabs, deal_status or deal_direction"
             end
    page_values = options.delete(:page_values)
    page_value = page_values[symbol]
    array_value = options.delete(:array_value)
    options.delete(:array_values)
    if array_value == page_value
      # inactive link - current tab or current filter value
      t ".#{prefix}_#{page_value}"
    else
      # active link - link to new tab or new filter value
      options[:id] = @user2.id
      options[symbol] = array_value
      key = ".#{prefix}_#{array_value}"
      # puts "users_helper.user_nav_link: link key = #{key}, link options = #{options}"
      link_to (t key), user_path(options)
    end
  end # user_nav_link

end

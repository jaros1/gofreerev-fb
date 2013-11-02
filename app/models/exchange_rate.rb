# require 'money/bank/google_currency'

BASE_CURRENCY = 'USD'

class ExchangeRate < ActiveRecord::Base

=begin
  create_table "exchange_rates", force: true do |t|
    t.string   "from_currency", limit: 3, null: false
    t.string   "to_currency",   limit: 3, null: false
    t.decimal  "exchange_rate"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "date",          limit: 8, null: false
  end

  add_index "exchange_rates", ["from_currency", "to_currency", "date"], name: "index_exchange_rates_pk", unique: true
=end


  # returns nil is exchange rate was not found
  # currency rate is found via USD as base currency
  # from_currency => USD => to_currency (requires only about 90 exchange rates per day)
  def self.exchange (from_amount, from_currency, to_currency, date=nil)
    # check params
    raise "invalid from_amount #{from_amount.class.name}" unless %w(Float BigDecimal).index(from_amount.class.name)
    raise "invalid from_currency" unless from_currency.class.name == 'String' and from_currency.size == 3 and from_currency == from_currency.upcase
    raise "invalid to_currency" unless to_currency.class.name == 'String' and to_currency.size == 3 and to_currency == to_currency.upcase
    today = Date.today.strftime("%Y%m%d")
    date = today unless date
    raise "invalid date" unless date.class.name == 'String' and date =~ /^20[0-9]{2}[0-1][0-9][0-3][0-9]$/
    begin
      dummy = Date.parse(date)
    rescue ArgumentError => e
      raise "invalid date"
    end
    raise "invalid date" if date > today

    # check for zero or identical currencies
    from_amount = from_amount.to_f
    if from_amount == 0 or from_currency. == to_currency
      # puts 'exchange: zero amount or identical currencies'
      to_amount = from_amount
      # puts "exchange: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      return to_amount
    end

    if from_currency == BASE_CURRENCY
      exchange_rate1 = 1.0
    else
      er1 = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, from_currency).first
      er1 = ExchangeRate.where('date < ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, from_currency).order('date desc').first unless er1
      return nil unless er1
      exchange_rate1 = er1.exchange_rate
    end

    if to_currency == BASE_CURRENCY
      exchange_rate2 = 1.0
    else
      er2 = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, to_currency).first
      er2 = ExchangeRate.where('date < ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, to_currency).order('date desc').first unless er2
      return nil unless er2
      exchange_rate2 = er2.exchange_rate
    end

    to_amount = from_amount / exchange_rate1 * exchange_rate2
    to_amount
  end # self.exchange


  # called from last line in application.html.erb to get new exchange rates.
  # about 90 exchange rates is saved each day
  # used in page header, user div mouse over texts and in user balance
  def self.fetch_exchange_rates
    # check if todays currency rates have already been fetched
    date = Date.today.strftime("%Y%m%d")
    return if ExchangeRate.where('date = ?', date).first

    # max request currency rates fromm bank once every 6 hours (about 165 requests)
    s = Sequence.find_by_name('last_money_bank_request')
    return if s and s.value >= Time.current_hour_no - 6

    # run in sub process with no wait so that current user don't has to wait
    ExchangeRate.fork_with_new_connection do

      # necessary to manage activerecord connections since we are forking
      ActiveRecord::Base.connection.reconnect!

      # create/update last_money_bank_request sequence
      if !s
        s = Sequence.new
        s.name = 'last_money_bank_request'
      end
      s.value = Time.current_hour_no

      # get all available currency rates - about 90 currency rates
      from = BASE_CURRENCY
      usd_rates = ExchangeRate.get_all_exchange_rates(from)
      if usd_rates.size < 50
        puts "Error: found less than 50 exchange rates from default money bank"
        puts "rates = #{usd_rates}"
        puts "next request in 6 hours"
        s.save!
        return
      end

      # save currency rates and update sequence
      transaction do
        usd_rates.each do |to, rate|
          er = ExchangeRate.new
          er.date = date
          er.from_currency = from
          er.to_currency = to
          er.exchange_rate = rate
          er.save!
        end # each
        s.save!
      end # transaction

    end # fork_with_new_connection
  end # fetch_exchange_rates



  def self.get_all_exchange_rates (from_currency)
    exchange_rates = {}
    Money::Currency.table.collect { |a| a[1][:iso_code] }.each do |to_currency|
      next if to_currency == from_currency
      begin
        exchange_rate = Money.default_bank.get_rate(from_currency, to_currency)
        exchange_rates[to_currency] = exchange_rate
      rescue Money::Bank::UnknownRate => e
        nil # ignore currencies with unknown exchange rates
      end
    end # each
    exchange_rates
  end # get_all_rates

end # ExchangeRate

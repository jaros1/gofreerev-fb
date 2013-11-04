# http://www.exchange-rates.org/ and http://www.exchangerates.org.uk
# can be used to find historical exchange rates.

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

  # cache last set of exchange rates received from default money bank
  def self.cache_exchange_rates
    today = Sequence.get_last_exchange_rate_date
    ers = ExchangeRate.where("date = ?", today)
    if ers.size == 0
      today = ExchangeRate.order("date desc").first.date
      ers = ExchangeRate.where("date = ?", today)
    end
    @@exchange_rates = {}
    ers.each { |er| @@exchange_rates[er.to_currency] = er.exchange_rate }
    @@today = today
  end # self.cache_exchange_rates


  # returns nil is exchange rate was not found
  # currency rate is found via USD as base currency
  # from_currency => USD => to_currency (requires only about 90 exchange rates per day)
  def self.exchange (from_amount, from_currency, to_currency, date=nil)
    # check params
    raise "invalid from_amount #{from_amount.class.name}" unless %w(Float BigDecimal).index(from_amount.class.name)
    raise "invalid from_currency" unless from_currency.class.name == 'String' and from_currency.size == 3 and from_currency == from_currency.upcase
    raise "invalid to_currency" unless to_currency.class.name == 'String' and to_currency.size == 3 and to_currency == to_currency.upcase
    date = date.strftime("%Y%m%d") unless [NilClass, String].index(date.class) # convert date and time to string
    if defined? @@today
      cache = true if date and date > @@today # refresh cache
    else
      cache = true
    end
    ExchangeRate.cache_exchange_rates if cache
    date = @@today unless date
    puts "date = #{date}, @@today = #{@@today}"
    raise "invalid date" unless date.to_s.yyyymmdd? and date <= @@today

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
    elsif date == @@today
      exchange_rate1 = @@exchange_rates[from_currency]
      return nil unless exchange_rate1
    else
      er1 = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, from_currency).first
      er1 = ExchangeRate.where('date < ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, from_currency).order('date desc').first unless er1
      return nil unless er1
      exchange_rate1 = er1.exchange_rate
    end

    if to_currency == BASE_CURRENCY
      exchange_rate2 = 1.0
    elsif date == @@today
      exchange_rate2 = @@exchange_rates[to_currency]
      return nil unless exchange_rate2
    else
      er2 = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, to_currency).first
      er2 = ExchangeRate.where('date < ? and from_currency = ? and to_currency = ?', date, BASE_CURRENCY, to_currency).order('date desc').first unless er2
      return nil unless er2
      exchange_rate2 = er2.exchange_rate
    end

    to_amount = from_amount / exchange_rate1 * exchange_rate2
    to_amount
  end # self.exchange


  # called from last line in application.html.erb to fetch new exchange rates.
  # about 90 exchange rates is saved every day
  def self.fetch_exchange_rates
    # check if currency rates for today have already been read and saved in db
    today = Date.today.strftime("%Y%m%d")
    s = Sequence.get_last_exchange_rate_date
    return if s and s == today # currency rates are up-to-date

    # currency rates are not up-to-date
    # max request currency rates fromm bank once every 6 hours (about 165 currency lookups in each request)
    s = Sequence.get_last_money_bank_request
    return if s and s >= Time.current_hour_no - 6 # error in last default money bank lookup - wait

    # run in sub process with no wait so that current user don't has to wait
    # todo: add exception handler and dump any error to log. See fork in application_controller.fetch_user
    ExchangeRate.fork_with_new_connection do

      begin

        # wait until actual page has been rendered to user
        sleep(2)

          # necessary to manage activerecord connections since we are forking
        ActiveRecord::Base.connection.reconnect!

        # get all available currency rates - about 90 currency rates
        from = BASE_CURRENCY
        usd_rates = ExchangeRate.get_all_exchange_rates(from)
        if usd_rates.size < 50
          puts "Error: found less than 50 exchange rates from default money bank"
          puts "rates = #{usd_rates}"
          puts "next currency request in 6 hours"
          ExchangeRate.set_last_money_bank_request(Time.current_hour_no)
          return
        end

        # save currency rates and update sequence
        transaction do
          usd_rates.each do |to, rate|
            er = ExchangeRate.new
            er.date = today
            er.from_currency = from
            er.to_currency = to
            er.exchange_rate = rate
            er.save!
          end # each
          # create/update last_exchange_rate_date - used when caching exchange rates of "today
          Sequence.set_last_money_bank_request(nil)
          Sequence.set_last_exchange_rate_date(today)
        end # transaction
      rescue Exception => e
        puts "ExchangeRate.fetch_exchange_rates"
        puts "Error when fetching and saving exchange rates from default money bank"
        puts "Exception: #{e.message.to_s}"
        puts "Backtrace: " + e.backtrace.join("\n")
      end # begin

    end # fork_with_new_connection
  end # fetch_exchange_rates


  # get all exchange rates from default money bank
  # about 165 currencies (90 valid / 75 unknown)
  def self.get_all_exchange_rates (from_currency)
    exchange_rates = {}
    Money::Currency.table.collect { |a| a[1][:iso_code] }.each do |to_currency|
      next if to_currency == from_currency
      begin
        exchange_rate = Money.default_bank.get_rate(from_currency, to_currency)
        exchange_rates[to_currency] = exchange_rate
      rescue Money::Bank::UnknownRate => e
        nil
      end
    end # each
    exchange_rates
  end # get_all_rates


end # ExchangeRate

# require 'money/bank/google_currency'

class ExchangeRate < ActiveRecord::Base

=begin
  create_table "exchange_rates", force: true do |t|
    t.string   "from_currency",    limit: 3, null: false
    t.string   "to_currency",      limit: 3, null: false
    t.decimal  "exchange_rate"
    t.datetime "exchange_rate_at"
    t.string   "request_update",   limit: 1
    t.datetime "last_request_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
=end


  # returns nil is exchange rate was not found
  # missing exchange rates is placed in a request queue and is processed batch
  # should be available in next user request
  def self.exchange (from_amount, from_currency, to_currency)
    # check params
    raise "invalid from_amount #{from_amount.class.name}" unless %w(Float BigDecimal).index(from_amount.class.name)
    raise "invalid from_currency" unless from_currency.class.name == 'String' and from_currency.size == 3 and from_currency == from_currency.upcase
    raise "invalid to_currency" unless to_currency.class.name == 'String' and to_currency.size == 3 and to_currency == to_currency.upcase
    # check for zero or identical currencies
    from_amount = from_amount.to_f
    if from_amount == 0 or from_currency. == to_currency
      # puts 'exchange: zero amount or identical currencies'
      to_amount = from_amount
      # puts "exchange: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      return to_amount
    end
    # find exchange rate - exchanges rates are fetch batch - refreshed once every day on request
    er = ExchangeRate.find_by_from_currency_and_to_currency(from_currency, to_currency)
    unless er
      # not converter. Request for exchange rate requested
      # puts 'exchange: exchange rate not found - request has been sent to bank'
      er = ExchangeRate.new
      er.from_currency = from_currency
      er.to_currency = to_currency
      er.request_update = 'Y'
      er.save!
      to_amount = nil
      # puts "exchange: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      return to_amount
    end
    unless er.exchange_rate
      # no exchange rate yet
      # puts 'exchange: exchange rate not ready yet'
      to_amount = nil
      # puts "exchange: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      return from_amount
    end
    if er.request_update != 'Y' and 1.day.since(er.exchange_rate_at) < Time.new
      # old exchange rate - request new update
      # puts 'exchange: using old exchange rate'
      er.request_update = 'Y'
      er.save!
    end
    # convert.
    to_amount = from_amount * er.exchange_rate
    # puts "exchange: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
    to_amount
  end # self.exchange


=begin
  # https://gist.github.com/danieldbower/842562
  # Logic for forking connections
  # The forked process does not have access to static vars as far as I can discern, so I've done some stuff to check if the op threw an exception.
  def self.fork_with_new_connection
    # Store the ActiveRecord connection information
    config = ActiveRecord::Base.remove_connection

    pid = fork do
    # tracking if the op failed for the Process exit
      success = true

      begin
        ActiveRecord::Base.establish_connection(config)
        # This is needed to re-initialize the random number generator after forking (if you want diff random numbers generated in the forks)
        srand

        # Run the closure passed to the fork_with_new_connection method
        yield

      rescue Exception => exception
        puts ('Forked operation failed with exception: ' + exception)
        # the op failed, so note it for the Process exit
        success = false

      ensure
        ActiveRecord::Base.remove_connection
        Process.exit! success
      end
    end

    # Restore the ActiveRecord connection information
    ActiveRecord::Base.establish_connection(config)

    #return the process id
    pid
  end  # fork_with_new_connection
=end


  # called from last line in application.html.erb - any new exchange rates should be ready in next request.
  def self.fetch_exchange_rates
    ers = ExchangeRate.where("request_update = 'Y' and (last_request_at is null or last_request_at < ?)", 1.hour.ago)
    return if ers.size == 0

    # run in sub process with no wait
    ExchangeRate.fork_with_new_connection do

      #necessary to manage activerecord connections since we are forking
      ActiveRecord::Base.connection.reconnect!

      b = Money.default_bank
      ExchangeRate.where("request_update = 'Y'").each do |er|
        # check if exchange rate has been updated in an other process
        er.reload
        next if er.request_update != 'Y'
        next if er.last_request_at and er.last_request_at > 1.hour.ago
        # update exchange_rate
        er.last_request_at = Time.new
        begin
          er.exchange_rate = b.get_rate(er.from_currency, er.to_currency)
          # OK
          er.exchange_rate_at = er.last_request_at
          er.request_update = 'N'
        rescue Exception => e
          puts "fetch_exchange_rates: #{e.message}"  # ignore errors - try again in 1 hour
        end
        er.save!
      end # each
    end # fork_with_new_connection
  end # fetch_exchange_rates


end # ExchangeRate

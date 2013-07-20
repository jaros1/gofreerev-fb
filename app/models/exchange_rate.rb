require 'money/bank/google_currency'

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

  def self.exchange (from_amount, from_currency, to_currency)
    # check for zero or identical currencies
    return from_amount.to_money(to_currency) if from_amount.to_f == 0 or from_currency == to_currency
    from_amount = from_amount.to_s.to_money(from_currency) if from_amount.class.name != 'Money'
    # find exchange rate - exchanges rates are fetch batch - refreshed once every day on request
    er = ExchangeRate.find_by_from_currency_and_to_currency(from_currency, to_currency)
    if !er
      # not converter. Request for exchange rate requested
      er = ExchangeRate.new
      er.from_currency = from_currency
      er.to_currency = to_currency
      er.request_update = 'Y'
      er.save!
      return from_amount
    end
    if !er.exchange_rate
      # no exchange rate yet
      return from_amount
    end
    if er.request_update != 'Y' and 1.day.since(er.exchange_rate_at) < Time.new
      # old exchange rate - request new update
      er.request.update = 'Y'
      er.save!
    end
    # convert
    Money.add_rate(from_currency, to_currency, er.exchange_rate)
    from_amount.exchange_to(to_currency)
  end

  # self.exchange


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
        puts ("Forked operation failed with exception: " + exception)
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


  # called from last line in application.html.erb - any new exchange rates should be ready in next request.
  def self.fetch_exchange_rates
    ers = ExchangeRate.where("request_update = 'Y' and (last_request_at is null or last_request_at < ?)", 1.hour.ago)
    return if ers.size == 0

    # run in sub process with no wait
    ExchangeRate.fork_with_new_connection do

      #necessary to manage activerecord connections since we are forking
      ActiveRecord::Base.connection.reconnect!

      b = Money::Bank::GoogleCurrency.new
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

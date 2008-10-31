module Politics

  def self.log=(value)
    @log = log
  end
  
  def self.log
    @log ||= if defined?(RAILS_DEFAULT_LOGGER)
      RAILS_DEFAULT_LOGGER
    else
      require 'logger'
      Logger.new(STDOUT)
    end
  end
end

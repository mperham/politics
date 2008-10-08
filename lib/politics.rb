require 'logger'

module Politics

  def self.log=(value)
    @log = log
  end
  
  def self.log
    @log ||= Logger.new(STDOUT)
  end
end

require 'logger'

module Politics
  LOG = Logger.new(STDOUT)
  
  def self.log(msg)
    LOG.info(msg)
  end
end

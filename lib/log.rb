# Log using local methods
# Local: provide the log level as a symbol (:debug, :info, :error, etc)

class Log
  def self.add(level, message)

    if defined? Rails.logger
      Rails.logger.send(level, message)
    else
      p "#{level} || #{message}"
    end
  end
end

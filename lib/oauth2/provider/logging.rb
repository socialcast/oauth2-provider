require "logger"

module OAuth2::Provider
  module Logging
    SEVERITY_MAPPING = {
      :debug => Logger::Severity::DEBUG,
      :info => Logger::Severity::INFO,
      :warn => Logger::Severity::WARN,
      :error => Logger::Severity::ERROR,
      :fatal => Logger::Severity::FATAL
    }

    def log(message, extra = {})
      return unless OAuth2::Provider.logger
      extra[:level] ||= :info
      OAuth2::Provider.logger.add SEVERITY_MAPPING[extra[:level]], ["[OAUTH2-PROVIDER]", Time.now.utc.strftime("%F %T"), message].join(" ") 
      nil
    end
  end
end

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

    def set_log_context(context)
      @logging_context = context
    end

    def clear_log_context
      @logging_context = nil
    end

    def log(message, extra = {})
      rack_env = self.respond_to?(:env) ? env : nil
      logger = OAuth2::Provider.logger || (rack_env && rack_env['rack.logger'])
      return unless logger

      extra = (@logging_context && @logging_context.merge(extra)) || extra
      extra[:level] ||= :info
      extra[:request_id] ||= (rack_env && rack_env['http_x_request_id']) || 'N/A'

      logger.add SEVERITY_MAPPING[extra[:level]], format_log_message(message, extra)
      nil
    end

    private

    def format_log_message(message, extra = {})
      [ "[#{extra[:component] || 'OAUTH2-PROVIDER'}]", extra[:request_id] || "N/A", Time.now.iso8601, '-', message].join(" ") 
    end
  end
end

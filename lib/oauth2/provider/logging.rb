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
      return unless current_logger

      extra = (@logging_context && @logging_context.merge(extra)) || extra
      extra[:level] ||= :info
      extra[:request_id] ||= (get_env_property('http_x_request_id') || 'N/A')

      current_logger.add SEVERITY_MAPPING[extra[:level]], format_log_message(message, extra)
      nil
    end

    private
   
    # FIXME this is a little gross, but it makes it easy to stub.
    def get_env_property(name)
      (self.respond_to?(:env) ? env : {})[name]
    end

    def current_logger
      OAuth2::Provider.logger || get_env_property('rack.logger')
    end

    def format_log_message(message, extra = {})
      [ "[#{extra[:component] || 'OAUTH2-PROVIDER'}]", extra[:request_id] || "N/A", Time.now.utc.iso8601, '-', message].join(" ") 
    end
  end
end

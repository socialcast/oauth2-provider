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
      env['log_context'] = context
    end

    def clear_log_context
      set_log_context nil 
    end

    def log(message, extra = {})
      return unless current_logger

      extra = (log_context && log_context.merge(extra)) || extra
      extra[:level] ||= :info
      extra[:request_id] ||= (env['http_x_request_id'] || 'N/A')

      current_logger.add SEVERITY_MAPPING[extra[:level]], format_log_message(message, extra)
      nil
    end

    def portable_logger
      PortableLogger.new env
    end

    private

    def log_context
      env['log_context']
    end
   
    def current_logger
      env['rack.logger']
    end

    def format_log_message(message, extra = {})
      [ "[#{extra[:component] || 'OAUTH2-PROVIDER'}]", extra[:request_id] || "N/A", Time.now.utc.iso8601, '-', message].join(" ") 
    end

    class PortableLogger
      include Logging

      attr_reader :env

      def initialize(env)
        @env = env
      end
    end
  end
end

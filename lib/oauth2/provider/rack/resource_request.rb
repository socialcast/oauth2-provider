require 'rack/auth/abstract/request'

module OAuth2::Provider::Rack
  class ResourceRequest < Rack::Request
    include Responses
    include OAuth2::Provider::Logging

    delegate :has_scope?, :to => :authorization


    def initialize(env)
      @env = env
      set_log_context :component => "OAUTH2-PROVIDER.RESOURCE-REQUEST"
      super env
    end 
    def token
      token_from_param || token_from_header
    end

    def has_token?
      !token.nil?
    end

    def token_from_param
      params["oauth_token"]
    end

    def token_from_header
      if authorization_header.provided?
        authorization_header.params
      end
    end

    def authorization_header
      @authorization_header ||= Rack::Auth::AbstractRequest.new(env)
    end

    def authenticate_request!(options, &block)
      if authenticated?
        if options[:scope].nil? || has_scope?(options[:scope])
          yield
        else
          insufficient_scope!
        end
      else
        authentication_required!
      end
    end

    def authorization
      validate_token!
      @authorization
    end

    def authenticated?
      authorization.present?
    end

    def resource_owner
      authorization && authorization.resource_owner
    end

    def access_token
      validate_token!
      @access_token
    end

    def validate_token!
      if has_token? && @token_validated.nil?
        @token_validated = true
        block_invalid_request
        block_invalid_token

        # TODO log token hash
        msg = "Verified authorization for #{@authorization.client.name} (#{@authorization.client.oauth_identifier})"
        msg += @authorization.expires_at ? " until #{@authorization.expires_at.utc.iso8601}" : " permanently"
        msg += " next refresh in #{(@access_token.expires_at - Time.now).floor} second(s)" 
        log msg 
      end
    end

    def block_invalid_request
      if token_from_param && token_from_header && (token_from_param != token_from_header)
        log "Conflicting tokens provided in header and parameters.", :level => :error
        invalid_request! 'both authorization header and oauth_token provided, with conflicting tokens'
      end
    end

    def block_invalid_token
      @access_token = OAuth2::Provider.access_token_class.find_by_access_token(token)
      @authorization = access_token.authorization if access_token
      if @access_token.nil?
        log "Invalid token: No token supplied", :level => :error
        authentication_required! 'invalid_token' 
      elsif @access_token.expired?
        log "Invalid token: Supplied token is expired", :level => :error
        authentication_required! 'invalid_token' 
      end
    end
  end
end

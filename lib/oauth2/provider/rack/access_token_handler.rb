require 'httpauth'

module OAuth2::Provider::Rack
  class AccessTokenHandler
    include Rack::Logster::Logging

    attr_reader :app, :env, :request

    def initialize(app, env)
      @app = app
      @env = env
      @request = env['oauth2']
      set_log_context :component => "OAUTH2-PROVIDER.TOKEN-ENDPOINT"
    end

    def process
      if request.post?
        block_unsupported_grant_types || handle_basic_auth_header || block_invalid_clients || handle_grant_type
      else
        error "This endpoint only supports POST"
        Responses.only_supported 'POST'
      end
    end

    def handle_basic_auth_header
      return unless request.env['HTTP_AUTHORIZATION'] =~ /^Basic/
      @env['oauth2'].params['client_id'], @env['oauth2'].params['client_secret'] = HTTPAuth::Basic.unpack_authorization(request.env['HTTP_AUTHORIZATION'])
      nil
    end

    def handle_grant_type
      grant_type = request.params["grant_type"]
      info "Processing #{grant_type} grant request..."
      send grant_type_handler_method(grant_type)
    end

    def handle_password_grant_type
      with_required_params 'username', 'password' do |username, password|
        if resource_owner = OAuth2::Provider.resource_owner_class.authenticate_with_username_and_password(username, password)
          info "Authenticated #{username} with the supplied credentials"
          token_response OAuth2::Provider.access_token_class.create!(
            :authorization => OAuth2::Provider.authorization_class.create!(:resource_owner => resource_owner, :client => oauth_client)
          )
        else
          error "Failed to authenticate #{username} with the supplied credentials"
          Responses.json_error 'invalid_grant'
        end
      end
    end

    def handle_authorization_code_grant_type
      with_required_params 'code', 'redirect_uri' do |code, redirect_uri|
        if token = oauth_client.authorization_codes.claim(code, redirect_uri)
          # TODO log token hash
          info "Authorization code successfully redeemed"
          token_response token
        else
          # TODO log token hash
          error "Failed to claim supplied authorization code"
          Responses.json_error 'invalid_grant'
        end
      end
    end

    def handle_refresh_token_grant_type
      with_required_params 'refresh_token' do |refresh_token|
        if token = oauth_client.access_tokens.refresh_with(refresh_token, portable_logger)
          # TODO log token hash
          info "Access token successfully refreshed"
          token_response token
        else
          # TODO log token hash
          error "Failed to refresh with supplied token"
          Responses.json_error 'invalid_grant'
        end
      end
    end

    def handle_client_credentials_grant_type
      token_response OAuth2::Provider.access_token_class.create!(
        :authorization => OAuth2::Provider.authorization_class.create!(:resource_owner => oauth_client, :client => oauth_client),
        :refresh_token => nil
      ).tap { info "Issuing authorization for authenticated client..." }
    end

    def with_required_params(*names, &block)
      missing_params = names - request.params.keys
      if missing_params.empty?
        yield *request.params.values_at(*names)
      else
        error "Missing parameter(s) #{missing_params.join(", ")}"
        if missing_params.size == 1
          Responses.json_error 'invalid_request', :description => "missing '#{missing_params.join}' parameter"
        else
          describe_parameters = missing_params.map{|x| "'#{x}'"}.join(", ")
          Responses.json_error 'invalid_request', :description => "missing #{describe_parameters} parameters"
        end
      end
    end

    def token_response(token)
      json = token.as_json.tap do |json|
        json[:state] = request.params['state'] if request.params['state']
      end
      [200, {'Content-Type' => 'application/json', 'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate'}, [ActiveSupport::JSON.encode(json)]]
    end

    def block_unsupported_grant_types
      with_required_params 'grant_type' do |grant_type|
        unless respond_to?(grant_type_handler_method(grant_type), true)
          error "Unsupported grant type: #{grant_type}"
          Responses.json_error 'unsupported_grant_type'
        end
      end
    end

    def block_invalid_clients
      with_required_params 'grant_type', 'client_id', 'client_secret' do |grant_type, client_id, client_secret|
        @oauth_client = OAuth2::Provider.client_class.find_by_oauth_identifier_and_oauth_secret(client_id, client_secret)
        if @oauth_client.nil?
          # TODO log client identifier
          error "No client matches supplied credentials"
          Responses.json_error 'invalid_client'
        elsif !@oauth_client.allow_grant_type?(grant_type)
          error "Client #{@oauth_client.name} (#{client_id}) may not use the #{grant_type} grant type"
          Responses.json_error 'unauthorized_client'
        else
          info "Client #{@oauth_client.name} (#{client_id}) authenticated"
          nil
        end
      end
    end

    def oauth_client
      @oauth_client
    end

    def grant_type_handler_method(grant_type)
      "handle_#{grant_type}_grant_type"
    end
  end
end

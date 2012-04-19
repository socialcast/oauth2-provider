module OAuth2::Provider::Rack
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      logger = Rack::Logster::Logging::PortableLogger.new(env)

      begin
        request = env['oauth2'] = ResourceRequest.new(env)

        response = catch :oauth2 do
          if request.path == OAuth2::Provider.access_token_path
            handle_access_token_request(env)
          else
            @app.call(env)
          end
        end
      rescue InvalidRequest => e
        logger.error "Invalid request. Responding with Bad Request due to '#{e}'"
        [400, {}, e.message]
      end
    end

    def handle_access_token_request(env)
      AccessTokenHandler.new(@app, env).process
    end
  end
end

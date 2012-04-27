module OAuth2::Provider::Models::AuthorizationCode
  extend ActiveSupport::Concern

  included do
    include OAuth2::Provider::Models::TokenExpiry, OAuth2::Provider::Models::RandomToken
    self.default_token_lifespan = 1.minute

    delegate :client, :resource_owner, :to => :authorization
    validates_presence_of :authorization, :code, :expires_at, :redirect_uri
    
    attr_accessible
    attr_accessible :code, :expires_at, :redirect_uri, :authorization, :as => :authority
  end

  def initialize(*args)
    super
    assign_attributes args.first, :as => :authority
    self.code ||= self.class.unique_random_token(:code)
  end

  module ClassMethods
    def claim(code, redirect_uri)
      if authorization_code = find_by_code_and_redirect_uri(code, redirect_uri)
        if authorization_code.fresh?
          authorization_code.destroy
          authorization_code.authorization.access_tokens.create!
        end
      end
    end
  end
end

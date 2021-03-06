module OAuth2::Provider::Models::AccessToken
  extend ActiveSupport::Concern

  included do
    include OAuth2::Provider::Models::TokenExpiry, OAuth2::Provider::Models::RandomToken
    self.default_token_lifespan = 1.month

    validates_presence_of :authorization, :access_token
    validate :expires_at_isnt_greater_than_authorization

    delegate :scope, :has_scope?, :client, :resource_owner, :to => :authorization
  end

  def initialize(attributes = {}, *args, &block)
    attributes ||= {} # Mongoid passes in nil
    super attributes.reverse_merge(
      :access_token => self.class.unique_random_token(:access_token),
      :refresh_token => self.class.unique_random_token(:refresh_token)
    )
  end

  def as_json(options = {})
    {"access_token" => access_token}.tap do |result|
      result["expires_in"] = expires_in if expires_at.present?
      result["refresh_token"] = refresh_token if refresh_token.present?
    end
  end

  def refreshable?
    refresh_token.present? && authorization.fresh?
  end

  private

  def expires_at_isnt_greater_than_authorization
    if !authorization.nil? && authorization.expires_at
      unless expires_at.nil? || expires_at <= authorization.expires_at
        errors.add(:expires_at, :must_be_less_than_authorization)
      end
    end
  end

  module ClassMethods
    def refresh_with(refresh_token, logger = nil)
      if !refresh_token
        logger.error "Refresh Failed: No refresh token provided" if logger
        return nil
      end

      if token = find_by_refresh_token(refresh_token)
        if token.refreshable?
          new(:authorization => token.authorization).tap do |result|
            if result.authorization.expires_at && result.authorization.expires_at < result.expires_at
              result.expires_at = result.authorization.expires_at
            end
            result.save!.tap{ logger.info "Refreshed session until #{result.expires_at.utc}" if logger }
          end
        else
          logger.error "Refresh Failed: refresh token '#{refresh_token}' is not refreshable." if logger
        end
      else
        logger.error "Refresh Failed: no token matching '#{refresh_token}' not found" if logger
      end
    end
  end
end

# frozen_string_literal: true

module CloudConnector
  # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Not a mixin, valid use case.
  module Tokens
    extend self

    @key_loader = CachingKeyLoader.new

    # root_group_ids: Billable root group IDs to filter by. Only relevant when issuing new tokens.
    # extra_claims: JWT claims to be included. Only relevant when issuing new tokens.
    def get(root_group_ids: [], extra_claims: {})
      return build_new_token(root_group_ids, extra_claims) if use_self_signed_token?

      load_stored_token
    end

    private

    def build_new_token(root_group_ids, extra_claims)
      jwk = @key_loader.private_jwk

      issuer = TokenIssuer.new(
        name_or_url: Doorkeeper::OpenidConnect.configuration.issuer,
        subject: Gitlab::CurrentSettings.uuid,
        realm: ::CloudConnector.gitlab_realm,
        active_add_ons: active_add_ons_for(root_group_ids),
        ttl: 1.hour,
        jwk: jwk,
        extra_claims: extra_claims
      )

      token_counter.increment(kid: jwk.kid)

      issuer.token
    end

    def load_stored_token
      TokenLoader.new.token
    end

    def use_self_signed_token?
      return true if ::Gitlab::Saas.feature_available?(:cloud_connector_self_signed_tokens)
      return true if ::Ai::Setting.self_hosted?

      Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
    end

    def active_add_ons_for(root_group_ids)
      GitlabSubscriptions::AddOn.active(root_group_ids).filter_map do |add_on|
        # Renaming the code_suggestions add-on to duo_pro would be complex and risky
        # so we are still using the legacy name is parts of the code.
        # The mapping is needed elsewhere because of third-party integrations that rely on our API.
        add_on.name == 'code_suggestions' ? 'duo_pro' : add_on.name
      end
    end

    def token_counter
      ::Gitlab::Metrics.counter(
        :cloud_connector_tokens_issued_total,
        'Total number of Cloud Connector tokens issued',
        worker_id: ::Prometheus::PidProvider.worker_id
      )
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end

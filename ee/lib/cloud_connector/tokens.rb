# frozen_string_literal: true

module CloudConnector
  # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Not a mixin, valid use case.
  module Tokens
    extend self

    @key_loader = CachingKeyLoader.new

    # Unit primitives that are fully migrated to the new token path
    ROLLED_OUT_UNIT_PRIMITIVES = %i[observability_all duo_workflow_execute_workflow security_scans
      amazon_q_integration duo_agent_platform].freeze

    # Retrieves a token for the specified unit primitive
    #
    # @param unit_primitive [Symbol] Requested unit primitive
    # @param resource [User], [Group], [Project] or [:instance]
    # @param extra_claims [Hash] Additional JWT claims to include
    # @return [String] JWT token
    def get(unit_primitive:, resource:, extra_claims: {})
      if use_self_signed_token?(unit_primitive)
        issue_token(unit_primitive, resource, extra_claims)
      else
        TokenLoader.new.token
      end
    end

    private

    def issue_token(unit_primitive, resource, extra_claims)
      if use_new_token_path_for?(unit_primitive, resource)
        jwk = @key_loader.private_jwk
        ::CloudConnector::TokenInstrumentation.instrument(jwk: jwk, operation_type: 'self_signed') do
          TokenIssuer.new(
            name_or_url: Doorkeeper::OpenidConnect.configuration.issuer,
            subject: Gitlab::CurrentSettings.uuid,
            realm: ::CloudConnector.gitlab_realm,
            active_add_ons: fetch_active_add_ons(resource),
            ttl: 1.hour,
            jwk: jwk,
            extra_claims: extra_claims
          ).token
        end
      else
        # Legacy implementation using service.access_token
        service = CloudConnector::AvailableServices.find_by_name(unit_primitive)
        service.access_token(resource, extra_claims: extra_claims)
      end
    end

    def fetch_active_add_ons(resource)
      add_on_names = GitlabSubscriptions::AddOn.names.keys
      GitlabSubscriptions::AddOnPurchase.for_active_add_ons(add_on_names, resource).uniq_add_on_names
    end

    def use_new_token_path_for?(unit_primitive, actor)
      return true if ROLLED_OUT_UNIT_PRIMITIVES.include?(unit_primitive)

      # Refer to https://gitlab.com/gitlab-org/cloud-connector/gitlab-cloud-connector/-/blob/main/config/services/anthropic_proxy.yml?ref_type=heads
      anthropic_proxy_ups = %i[generate_commit_message generate_issue_description resolve_vulnerability
        review_merge_request summarize_issue_discussions description_composer]

      case unit_primitive
      when :complete_code, :generate_code
        Feature.enabled?(:code_suggestions_new_tokens_path, actor)
      when *anthropic_proxy_ups
        Feature.enabled?(:anthropic_proxy_new_tokens_path, actor)
      else
        false
      end
    end

    def use_self_signed_token?(unit_primitive)
      return true if ::Gitlab::Saas.feature_available?(:cloud_connector_self_signed_tokens)

      # This should be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/543706
      return true if unit_primitive == :self_hosted_models
      return true if ::Ai::FeatureSetting.feature_for_unit_primitive(unit_primitive)&.self_hosted?

      Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end

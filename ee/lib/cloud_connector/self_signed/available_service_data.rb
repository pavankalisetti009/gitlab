# frozen_string_literal: true

module CloudConnector
  module SelfSigned
    class AvailableServiceData < BaseAvailableServiceData
      extend ::Gitlab::Utils::Override

      IGNORE_CUT_OFF_DATE_EXPIRED_LIST = %i[self_hosted_models sast duo_workflow].freeze

      attr_reader :backend

      def initialize(name, cut_off_date, bundled_with, backend)
        super(name, cut_off_date, bundled_with.keys)

        @bundled_with = bundled_with
        @backend = backend
      end

      override :free_access?
      def free_access?
        cut_off_date_expired_enabled? ? false : super
      end

      override :access_token
      def access_token(resource = nil, extra_claims: {})
        ::Gitlab::CloudConnector::SelfIssuedToken.new(
          audience: backend,
          subject: Gitlab::CurrentSettings.uuid,
          scopes: scopes_for(resource),
          extra_claims: extra_claims
        ).encoded
      end

      private

      def cut_off_date_expired_enabled?
        return false unless ::Gitlab.dev_or_test_env? || ::Gitlab.staging?
        return false if IGNORE_CUT_OFF_DATE_EXPIRED_LIST.include?(name)

        Feature.enabled?(:cloud_connector_cut_off_date_expired, :instance, type: :ops)
      end

      def scopes_for(resource)
        free_access? ? allowed_scopes_during_free_access : allowed_scopes_from_purchased_bundles_for(resource)
      end

      def allowed_scopes_from_purchased_bundles_for(resource)
        add_on_purchases_for(resource).uniq_add_on_names.flat_map do |name|
          # Renaming the code_suggestions add-on to duo_pro would be complex and risky
          # so we are still using the legacy name is parts of the code.
          # The mapping is needed elsewhere because of third-party integrations that rely on our API.
          add_on_name = name == 'code_suggestions' ? 'duo_pro' : name
          @bundled_with[add_on_name]
        end.uniq
      end

      def add_on_purchases_for(resource = nil)
        resource.is_a?(User) ? add_on_purchases_assigned_to(resource) : add_on_purchases(resource)
      end

      def allowed_scopes_during_free_access
        @bundled_with.values.flatten.uniq
      end
    end
  end
end

# frozen_string_literal: true

module EE
  module Projects
    module UpdatePagesService
      extend ::Gitlab::Utils::Override

      override :pages_deployment_attributes
      def pages_deployment_attributes(file, build)
        super.merge({
          path_prefix: path_prefix,
          expires_at: expires_at
        })
      end

      private

      def expires_at
        return unless ::Gitlab::CurrentSettings.pages_extra_deployments_default_expiry_seconds&.nonzero?
        return unless extra_deployment?

        ::Gitlab::CurrentSettings.pages_extra_deployments_default_expiry_seconds.seconds.from_now
      end
    end
  end
end

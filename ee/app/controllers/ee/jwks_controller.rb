# frozen_string_literal: true

module EE
  module JwksController
    extend ::Gitlab::Utils::Override

    private

    override :load_keys
    def load_keys
      return super unless ::Feature.enabled?(:cloud_connector_expose_keys, ::Feature.current_request)

      super + CloudConnector::Keys.all_as_pem
    end
  end
end

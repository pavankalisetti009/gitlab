# frozen_string_literal: true

module SecretsManagement
  class BaseSecretsManager < ApplicationRecord
    include Gitlab::InternalEventsTracking
    include SecretsManagers::PipelineHelper
    include SecretsManagers::UserHelper

    self.abstract_class = true

    STATUSES = {
      provisioning: 0,
      active: 1,
      deprovisioning: 2
    }.freeze

    state_machine :status, initial: :provisioning do
      state :provisioning, value: STATUSES[:provisioning]
      state :active, value: STATUSES[:active]
      state :deprovisioning, value: STATUSES[:deprovisioning]

      event :activate do
        transition all - [:active] => :active
      end

      event :initiate_deprovision do
        transition active: :deprovisioning
      end
    end

    # Server Configuration
    def self.jwt_issuer
      Gitlab.config.gitlab.base_url
    end

    def self.internal_server_url
      if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("internal_url")
        return Gitlab.config.openbao.internal_url
      end

      server_url
    end

    def self.server_url
      return SecretsManagement::OpenbaoTestSetup::SERVER_ADDRESS_WITH_HTTP if Rails.env.test?
      return Gitlab.config.openbao.url if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("url")

      default_openbao_server_url
    end

    def self.default_openbao_server_url
      "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:8200"
    end
    private_class_method :default_openbao_server_url

    private

    def aud
      self.class.server_url
    end

    def hex(value)
      value.unpack1('H*')
    end
  end
end

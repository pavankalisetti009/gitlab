# frozen_string_literal: true

module EE
  module UserSettings
    module SshKeysController
      extend ActiveSupport::Concern

      prepended do
        before_action :check_ssh_keys_enabled, only: [:index, :show, :create, :destroy]
      end

      private

      def check_ssh_keys_enabled
        return unless current_user.enterprise_user? && current_user.enterprise_group.disable_ssh_keys?

        render_404
      end
    end
  end
end

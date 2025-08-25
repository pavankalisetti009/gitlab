# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module MarkAdminBotRunnersAsHosted
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :mark_admin_bot_runners_as_hosted
          feature_category :hosted_runners
        end

        override :perform
        def perform
          return unless ::Gitlab::CurrentSettings.gitlab_dedicated_instance

          each_sub_batch do |sub_batch|
            sub_batch.each do |runner|
              next unless ::User.admin_bot.where(id: runner.creator_id).exists?

              CiHostedRunner.find_or_create_by!(runner_id: runner.id)
            end
          end
        end

        class ApplicationSetting < ApplicationRecord
          self.table_name = :application_settings
        end

        class CiHostedRunner < ::Ci::ApplicationRecord
          self.table_name = :ci_hosted_runners
        end
      end
    end
  end
end

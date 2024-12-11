# frozen_string_literal: true

module EE
  module UserDetail
    extend ActiveSupport::Concern

    prepended do
      belongs_to :provisioned_by_group, class_name: 'Group', optional: true, inverse_of: :provisioned_user_details
      belongs_to :enterprise_group, class_name: 'Group', optional: true, inverse_of: :enterprise_user_details

      scope :with_enterprise_group, -> { where.not(enterprise_group_id: nil) }

      attribute :onboarding_status, ::Gitlab::Database::Type::IndifferentJsonb.new
      store_accessor(
        :onboarding_status, :step_url, :email_opt_in, :initial_registration_type, :registration_type, :glm_content,
        :glm_source, :joining_project, :role, prefix: true
      )

      # Values here should match the role enums in app/validators/json_schemas/user_detail_onboarding_status.json
      def self.onboarding_status_roles
        {
          'software_developer' => 0,
          'development_team_lead' => 1,
          'devops_engineer' => 2,
          'systems_administrator' => 3,
          'security_analyst' => 4,
          'data_analyst' => 5,
          'product_manager' => 6,
          'product_designer' => 7,
          'other' => 8
        }
      end
    end
  end
end

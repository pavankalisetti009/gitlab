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
        :glm_source, prefix: true
      )
    end
  end
end

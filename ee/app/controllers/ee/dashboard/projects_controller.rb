# frozen_string_literal: true

module EE
  module Dashboard
    module ProjectsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action do
          push_licensed_feature(:adjourned_deletion_for_projects_and_groups)
        end
      end
    end
  end
end

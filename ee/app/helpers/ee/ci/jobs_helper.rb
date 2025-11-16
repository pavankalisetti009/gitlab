# frozen_string_literal: true

module EE
  module Ci
    module JobsHelper
      extend ::Gitlab::Utils::Override

      override :jobs_data
      def jobs_data(project, build)
        super.merge({ "duo_features_enabled" => project.duo_features_enabled.to_s })
      end
    end
  end
end

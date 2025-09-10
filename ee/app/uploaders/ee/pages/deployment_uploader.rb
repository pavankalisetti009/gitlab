# frozen_string_literal: true

module EE
  module Pages
    module DeploymentUploader
      extend ::Gitlab::Utils::Override

      override :trim_filename_if_needed
      def trim_filename_if_needed(filename)
        # Don't trim the filename on Geo secondary to maintain consistency. Otherwise,
        # Geo may not find the page deployments in the object storage during replication
        # or verification due to the trimmed filename.
        #
        # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/559196
        return super unless ::Gitlab::Geo.secondary?

        filename
      end
    end
  end
end

# frozen_string_literal: true

module EE
  module Search
    module Filter
      extend ::Gitlab::Utils::Override

      private

      override :filters
      def filters
        super.merge(
          language: params[:language],
          labels: params[:labels],
          label_name: params[:label_name],
          source_branch: params[:source_branch],
          not_source_branch: params[:not_source_branch]
        )
      end
    end
  end
end

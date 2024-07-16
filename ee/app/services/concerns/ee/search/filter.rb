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
          not_source_branch: params[:not_source_branch],
          author_username: params[:author_username],
          not_author_username: params[:not_author_username]
        )
      end
    end
  end
end

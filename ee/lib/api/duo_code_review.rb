# frozen_string_literal: true

module API
  class DuoCodeReview < ::API::Base
    include APIGuard

    feature_category :code_review_workflow

    allow_access_with_scope :ai_features

    before do
      not_found! unless Gitlab.dev_or_test_env?

      authenticate!

      license_feature_available = ::License.feature_available?(:review_merge_request)
      global_feature_flag_enabled = Gitlab::Llm::Utils::FlagChecker.flag_enabled_for_feature?(:review_merge_request)

      not_found! unless license_feature_available && global_feature_flag_enabled
    end

    namespace 'duo_code_review' do
      resources :evaluations do
        params do
          requires :diffs, type: String,
            desc: 'Raw diffs to review'
          requires :mr_title, type: String,
            desc: 'Title of the merge request'
          requires :mr_description, type: String,
            desc: 'Description of the merge request'
          requires :files_content, type: Hash,
            desc: 'Full file contents, where keys are file paths and values are the file contents'
        end

        post do
          evaluation_response = Gitlab::Llm::Evaluators::ReviewMergeRequest.new(
            user: current_user,
            tracking_context: {
              request_id: SecureRandom.uuid,
              action: 'review_merge_request'
            },
            options: declared_params
          ).execute

          review_response = { review: evaluation_response }

          present review_response, with: Grape::Presenters::Presenter
        end
      end
    end
  end
end

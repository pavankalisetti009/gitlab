# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module MergeRequestActions
        extend ActiveSupport::Concern
        include ::Gitlab::QuickActions::Dsl

        included do
          desc { _('Change reviewers') }
          explanation { _('Change reviewers.') }
          execution_message { _('Changed reviewers.') }
          params '@user1 @user2'
          types MergeRequest
          condition do
            quick_action_target.allows_multiple_reviewers? &&
              quick_action_target.persisted? &&
              current_user.can?(:"admin_#{quick_action_target.to_ability_name}", project)
          end
          command :reassign_reviewer do |reassign_param|
            @updates[:reviewer_ids] = extract_users(reassign_param).map(&:id)
          end

          desc { _('Requests a Duo Code Review') }
          explanation { _('Requests a Duo Code Review') }
          execution_message { _('Request for a Duo Code Review queued.') }
          types MergeRequest
          condition do
            quick_action_target.ai_review_merge_request_allowed?(current_user)
          end
          command :duo_code_review do
            duo_code_review_bot = ::Users::Internal.duo_code_review_bot

            if quick_action_target.find_reviewer(duo_code_review_bot)
              ::MergeRequests::RequestReviewService
                .new(project: quick_action_target.project, current_user: current_user)
                .execute(quick_action_target, duo_code_review_bot)
            else
              @updates[:reviewer_ids] ||= quick_action_target.reviewers.map(&:id)
              @updates[:reviewer_ids] |= [duo_code_review_bot.id]
            end
          end
        end
      end
    end
  end
end

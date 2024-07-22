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
          types MergeRequest
          condition do
            quick_action_target.ai_review_merge_request_allowed?(current_user)
          end
          command :duo_code_review do
            if quick_action_target.ai_reviewable_diff_files.blank?
              @execution_message[:duo_code_review] =
                _("GitLab Duo didn't find any reviewable files. Code Review request skipped.")
            else
              @execution_message[:duo_code_review] = _('Request for a Duo Code Review queued.')

              Llm::ReviewMergeRequestService.new(current_user, quick_action_target).execute
            end
          end
        end
      end
    end
  end
end

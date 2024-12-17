# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module AmazonQActions
        extend ActiveSupport::Concern
        include ::Gitlab::QuickActions::Dsl

        included do
          desc { _('Use Amazon Q to streamline development workflow and project upgrades (Beta)') }
          explanation { _('Use Amazon Q to streamline development workflow and project upgrades (Beta)') }
          execution_message { _('Q got your message!') }
          params do
            case quick_action_target
            when ::Issue
              "<#{::Ai::AmazonQ::Commands::ISSUE_SUBCOMMANDS.join(' | ')}>"
            when ::MergeRequest
              "<#{::Ai::AmazonQ::Commands::MERGE_REQUEST_SUBCOMMANDS.join(' | ')}>"
            end
          end
          types Issue, MergeRequest
          condition do
            Ability.allowed?(current_user, :trigger_amazon_q, quick_action_target) &&
              (quick_action_target.is_a?(Issue) || quick_action_target.persisted?)
          end
          command :q do |input = "dev"|
            sub_command, *comment_words = input.strip.split(' ', 2)
            case quick_action_target
            when ::Issue
              unless ::Ai::AmazonQ::Commands::ISSUE_SUBCOMMANDS.include?(sub_command)
                @execution_message[:q] = "Could not apply Amazon Q command for issue"
                next
              end
            when ::MergeRequest
              unless ::Ai::AmazonQ::Commands::MERGE_REQUEST_SUBCOMMANDS.include?(sub_command)
                @execution_message[:q] = "Could not apply Amazon Q command for merge request"
                next
              end
            end
            comment = comment_words.join(' ')
            action_data = {
              command: sub_command,
              input: comment,
              source: quick_action_target,
              discussion_id: params[:discussion_id]
            }
            action_data[:input] = comment unless comment.empty?
            @updates[:amazon_q] = action_data
          end
        end
      end
    end
  end
end

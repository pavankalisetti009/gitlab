# frozen_string_literal: true

module Gitlab
  module Tracking
    # Class for tracking AI usage events.
    # @see doc/development/ai_features/usage_tracking.md for documentation
    module AiTracking
      extend AiUsageEventsRegistryDsl

      register_feature(:code_suggestions) do
        deprecated_events(code_suggestions_requested: 1) # old data

        events(
          code_suggestion_shown_in_ide: 2,
          code_suggestion_accepted_in_ide: 3,
          code_suggestion_rejected_in_ide: 4
        ) do |context|
          context.slice(*%w[unique_tracking_id suggestion_size language branch_name
            ide_name ide_vendor ide_version
            extension_name extension_version language_server_version
            model_name model_engine])
        end

        deprecated_events(code_suggestion_direct_access_token_refresh: 5) # old data
      end

      register_feature(:chat) do
        events(request_duo_chat_response: 6)
      end

      register_feature(:troubleshoot_job) do
        events(troubleshoot_job: 7) do |context|
          {
            job_id: context['job'].id,
            project_id: context['job'].project_id,
            pipeline_id: context['job'].pipeline&.id,
            merge_request_id: context['job'].pipeline&.merge_request_id
          }
        end
      end

      register_feature(:agentic_chat) do
        events(
          agent_platform_session_created: 8,
          agent_platform_session_started: 9,
          agent_platform_session_finished: 19,
          agent_platform_session_dropped: 20,
          agent_platform_session_stopped: 21,
          agent_platform_session_resumed: 22) do |context|
          {
            project_id: context['project']&.id,
            session_id: context['value'],
            flow_type: context['label'],
            environment: context['property']
          }
        end
      end

      register_feature(:code_review) do
        events(
          encounter_duo_code_review_error_during_review: 10,
          find_no_issues_duo_code_review_after_review: 11,
          find_nothing_to_review_duo_code_review_on_mr: 12,
          post_comment_duo_code_review_on_diff: 13,
          react_thumbs_up_on_duo_code_review_comment: 14,
          react_thumbs_down_on_duo_code_review_comment: 15,
          request_review_duo_code_review_on_mr_by_author: 16,
          request_review_duo_code_review_on_mr_by_non_author: 17,
          excluded_files_from_duo_code_review: 18
        )
      end
      # Current highest event ID: 22, next available: 23

      class << self
        def track_event(event_name, **context_hash)
          return unless AiTracking.registered_events.key?(event_name.to_s)

          event = build_event_model(event_name, context_hash)

          store_to_postgres(event)
          store_to_clickhouse(event)

          track_user_activity(context_hash[:user])
        end

        def track_user_activity(user)
          ::Ai::UserMetrics.refresh_last_activity_on(user)
        end

        private

        def base_attributes
          %w[user timestamp event namespace_id].freeze
        end

        def build_event_model(event_name, context_hash = {})
          context_hash = context_hash.with_indifferent_access

          attributes = apply_transformations(event_name, context_hash)

          basic_attributes = context_hash.slice(*base_attributes).merge(attributes.slice(*base_attributes))
          extra_attributes = attributes.except(*base_attributes)

          ::Ai::UsageEvent.new(basic_attributes.merge(event: event_name, extras: extra_attributes))
        end

        def store_to_clickhouse(event)
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          event.store_to_clickhouse
        end

        def store_to_postgres(event)
          event.store_to_pg
        end

        def apply_transformations(event_name, context_hash)
          result = {}.with_indifferent_access

          AiTracking.registered_transformations(event_name).each do |transformation|
            transformation_result = transformation.call(context_hash.merge(result))

            result.merge!(transformation_result)
          end.compact

          unless result[:namespace_id]
            guessed_namespace_id = guess_namespace_id(context_hash.merge(result))

            result[:namespace_id] = guessed_namespace_id if guessed_namespace_id
          end

          result
        end

        def guess_namespace_id(context_hash)
          related_namespace(context_hash)&.id
        end

        def related_namespace(context_hash)
          # Order matters. project should take precedence over namespace
          project = if context_hash[:project]
                      context_hash[:project]
                    elsif context_hash[:project_id]
                      ::Project.find_by_id(context_hash[:project_id])
                    end

          return project.project_namespace if project

          if context_hash[:namespace]
            context_hash[:namespace]
          elsif context_hash[:namespace_id]
            ::Namespace.find_by_id(context_hash[:namespace_id])
          end
        end
      end
    end
  end
end

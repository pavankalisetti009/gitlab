# frozen_string_literal: true

module Ci
  module Minutes
    class Notification
      PERCENTAGES = {
        not_set: 100,
        warning: 25,
        danger: 5,
        exceeded: 0
      }.freeze

      def initialize(project, namespace)
        @context = Ci::Minutes::Context.new(project, namespace)
        @stage = calculate_notification_stage if eligible_for_notifications?
      end

      def show_callout?(current_user)
        return false unless @stage
        return false unless @context.namespace
        return false unless current_user
        return false if callout_has_been_dismissed?(current_user)

        Ability.allowed?(current_user, :admin_ci_minutes, @context.namespace)
      end

      def text
        contextual_map.dig(stage, :text)
      end

      def style
        contextual_map.dig(stage, :style)
      end

      def no_remaining_minutes?
        stage == :exceeded
      end

      def running_out?
        [:danger, :warning].include?(stage)
      end

      def stage_percentage
        PERCENTAGES[stage]
      end

      def total
        context.total
      end

      def current_balance
        context.current_balance
      end

      def percentage
        context.percent_total_minutes_remaining.round
      end

      def eligible_for_notifications?
        context.shared_runners_minutes_limit_enabled?
      end

      def callout_data
        if @context.namespace.user_namespace?
          return {
            feature_id: callout_feature_id,
            dismiss_endpoint: Rails.application.routes.url_helpers.callouts_path
          }
        end

        {
          feature_id: callout_feature_id,
          dismiss_endpoint: Rails.application.routes.url_helpers.group_callouts_path,
          group_id: @context.namespace.root_ancestor.id
        }
      end

      private

      attr_reader :context, :stage

      def callout_feature_id
        "ci_minutes_limit_alert_#{stage}_stage"
      end

      def callout_has_been_dismissed?(current_user)
        if @context.namespace.user_namespace?
          current_user.dismissed_callout?(
            feature_name: callout_feature_id,
            ignore_dismissal_earlier_than: 30.days.ago
          )
        else
          current_user.dismissed_callout_for_group?(
            feature_name: callout_feature_id,
            group: @context.namespace,
            ignore_dismissal_earlier_than: 30.days.ago
          )
        end
      end

      def calculate_notification_stage
        precise_percentage = context.percent_total_minutes_remaining
        if precise_percentage <= PERCENTAGES[:exceeded]
          :exceeded
        elsif precise_percentage <= PERCENTAGES[:danger]
          :danger
        elsif precise_percentage <= PERCENTAGES[:warning]
          :warning
        end
      end

      def contextual_map
        {
          warning: {
            style: :warning,
            text: threshold_message
          },
          danger: {
            style: :danger,
            text: threshold_message
          },
          exceeded: {
            style: :danger,
            text: exceeded_message
          }
        }
      end

      def exceeded_message
        s_(
          "Pipelines|The %{namespace_name} namespace has reached its shared runner compute minutes quota. " \
            "To run new jobs and pipelines in this namespace's projects, buy additional compute minutes."
        ) % { namespace_name: context.namespace_name }
      end

      def threshold_message
        s_(
          "Pipelines|The %{namespace_name} namespace has %{current_balance} / %{total} " \
          "(%{percentage}%%) shared runner compute minutes remaining. When all compute minutes " \
          "are used up, no new jobs or pipelines will run in this namespace's projects."
        ) % {
          namespace_name: context.namespace_name,
          current_balance: current_balance,
          total: total,
          percentage: percentage
        }
      end
    end
  end
end

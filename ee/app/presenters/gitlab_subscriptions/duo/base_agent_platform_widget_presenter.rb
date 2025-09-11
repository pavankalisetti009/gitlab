# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    class BaseAgentPlatformWidgetPresenter
      include Gitlab::Utils::StrongMemoize

      def initialize(user)
        @user = user
      end

      def attributes
        return {} unless eligible?

        {
          duoAgentWidgetProvide: widget_attributes
        }
      end

      private

      attr_reader :user

      def widget_attributes
        {
          actionPath: action_path,
          stateProgression: state_progression
        }.merge(user_attributes)
      end

      def state
        if fully_enabled?
          :enabled
        elsif enabled_without_beta_features?
          :enabled_without_beta_features
        elsif only_duo_default_off?
          :only_duo_default_off
        elsif enabled_without_core?
          :enabled_without_core
        else
          :disabled
        end
      end
      strong_memoize_attr :state

      def state_progression
        case state
        when :enabled
          [:enabled]
        when :enabled_without_beta_features
          [:enableFeaturePreview, :enabled]
        when :enabled_without_core, :only_duo_default_off
          [:enablePlatform, :enabled]
        else
          [:enablePlatform, :enableFeaturePreview, :enabled]
        end
      end

      def user_attributes
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def action_path
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def eligible?
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def enabled_without_beta_features?
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def fully_enabled?
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def only_duo_default_off?
        raise NoMethodError, 'This method must be implemented in a subclass'
      end

      def enabled_without_core?
        raise NoMethodError, 'This method must be implemented in a subclass'
      end
    end
  end
end

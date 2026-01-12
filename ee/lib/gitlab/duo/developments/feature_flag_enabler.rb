# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class FeatureFlagEnabler
        # list of feature flags from these groups to ignore in development environments
        EXCLUDED_FEATURE_FLAGS = %i[
          use_claude_code_completion
          code_completion_opt_out_fireworks
          incident_fail_over_completion_provider
          incident_fail_over_generation_provider
          duo_ui_next # Breaks Chat UI still WIP

          # Model-specific feature flags disabled by default as they require specific configuration
          duo_agentic_chat_openai_gpt_5 # Ref: https://gitlab.com/gitlab-org/gitlab/-/issues/560561
        ].freeze

        def self.execute
          feature_flag_names = Feature::Definition.definitions.filter_map do |k, v|
            k if v.group == 'group::ai framework' ||
              v.group == 'group::agent foundations' ||
              v.group == "group::duo chat" ||
              v.group == "group::duo workflow" ||
              v.group == "group::custom models" ||
              v.group == "group::code creation"
          end

          feature_flag_names = feature_flag_names.flatten - EXCLUDED_FEATURE_FLAGS

          feature_flag_names.each do |ff|
            puts "Enabling the feature flag: #{ff}"
            Feature.enable(ff.to_sym)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumerPolicy < ::BasePolicy
      delegate { @subject.project }
      delegate { @subject.group }

      condition(:custom_flow, scope: :subject) do
        @subject.item.flow? && !@subject.item.foundational_flow?
      end

      condition(:third_party_flow, scope: :subject) do
        @subject.item.third_party_flow?
      end

      condition(:custom_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_flows)
      end

      condition(:third_party_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_third_party_flows)
      end

      condition(:foundational_flow, scope: :subject) do
        @subject.item.foundational_flow?
      end

      condition(:foundational_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :foundational_flows)
      end

      condition(:beta_foundational_flow, scope: :subject) do
        @subject.item.foundational_flow? &&
          ::Ai::Catalog::FoundationalFlow.beta?(@subject.item.foundational_flow_reference)
      end

      condition(:beta_features_enabled, scope: :subject) do
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          root_ancestor = @subject.project&.root_ancestor || @subject.group&.root_ancestor
          root_ancestor&.experiment_features_enabled || false
        else
          ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
        end
      end

      condition(:pinned_version_available, scope: :subject) do
        @subject.pinned_version.present?
      end

      condition(:pinned_version_draft, scope: :subject) do
        @subject.pinned_version.present? && @subject.pinned_version.draft?
      end

      rule do
        ~pinned_version_available |
          pinned_version_draft |
          (custom_flow & ~custom_flows_available) |
          (foundational_flow & ~foundational_flows_available) |
          (third_party_flow & ~third_party_flows_available) |
          (beta_foundational_flow & ~beta_features_enabled)
      end.prevent :execute_ai_catalog_item

      rule { beta_foundational_flow & ~beta_features_enabled }.prevent :read_ai_catalog_item_consumer
    end
  end
end

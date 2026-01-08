# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumerPolicy < ::BasePolicy
      delegate { @subject.project }
      delegate { @subject.group }

      condition(:flow, scope: :subject) do
        @subject.item.flow?
      end

      condition(:third_party_flow, scope: :subject) do
        @subject.item.third_party_flow?
      end

      condition(:flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_flows)
      end

      condition(:third_party_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_third_party_flows)
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
          (flow & ~flows_available) |
          (third_party_flow & ~third_party_flows_available)
      end.prevent :execute_ai_catalog_item
    end
  end
end

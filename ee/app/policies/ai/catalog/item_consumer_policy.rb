# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumerPolicy < ::BasePolicy
      delegate { @subject.project }
      delegate { @subject.group }

      condition(:flow) do
        @subject.item.flow?
      end

      condition(:flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.project, :ai_catalog_flows)
      end

      rule { flow & ~flows_available }.policy do
        prevent :execute_ai_catalog_item
      end
    end
  end
end

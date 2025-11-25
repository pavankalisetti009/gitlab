# frozen_string_literal: true

module Ai
  module Catalog
    module TestHelpers
      def enable_ai_catalog(enabled = true)
        allow(Ai::Catalog).to receive(:available?).and_return(enabled)
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_return(enabled)
      end
    end
  end
end

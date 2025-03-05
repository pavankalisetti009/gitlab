# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ModelConfigurations
        class TextEmbeddings < Base
          NAME = 'textembedding-gecko@003'

          def payload(content)
            {
              instances: content.map { |instance| { content: instance } }
            }
          end
        end
      end
    end
  end
end

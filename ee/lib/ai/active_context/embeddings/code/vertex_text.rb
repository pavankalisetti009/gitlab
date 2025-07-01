# frozen_string_literal: true

module Ai
  module ActiveContext
    module Embeddings
      module Code
        class VertexText < ::ActiveContext::Embeddings
          EMBEDDINGS_MODEL_CLASS = Gitlab::Llm::VertexAi::Embeddings::Text

          class << self
            # The caller of the `generate_embeddings` method should already have estimated
            # calculations of the size of `contents` so as not to exceed limits.
            # However, we cannot be certain that those calculations are accurate,
            # so we still need to handle the possibility of a "token limits exceeded" error here.
            def generate_embeddings(contents, unit_primitive:, model: nil, user: nil)
              tracking_context = { action: 'embedding' }

              generate_with_recursive_batch_splitting(
                contents,
                unit_primitive: unit_primitive,
                tracking_context: tracking_context,
                model: model,
                user: user
              )
            end

            private

            # This handles the `TokenLimitExceededError` coming from the embeddings generation call.
            # If the `TokenLimitExceededError` occurs, the `contents` array is split into 2
            # and the embeddings generation is called for each half batch.
            # This has to be done recursively because the new half batch might still exceed limits.
            def generate_with_recursive_batch_splitting(
              contents,
              unit_primitive:,
              tracking_context:,
              model: nil,
              user: nil
            )
              embeddings = EMBEDDINGS_MODEL_CLASS.new(
                contents,
                user: user,
                tracking_context: tracking_context,
                unit_primitive: unit_primitive,
                model: model
              ).execute

              embeddings.all?(Array) ? embeddings : [embeddings]

            rescue EMBEDDINGS_MODEL_CLASS::TokenLimitExceededError => e
              contents_count = contents.length
              if contents_count == 1
                # if we are still getting a `TokenLimitExceededError` even with a single content input, raise an error
                raise StandardError, "Token limit exceeded for single content input: #{e.message.inspect}"
              end

              # split the contents input into 2 arrays and recursively call
              # `generate_with_recursive_batch_splitting`
              embeddings = []
              half_batch_size = (contents_count / 2.0).ceil
              contents.each_slice(half_batch_size) do |batch_contents|
                embeddings += generate_with_recursive_batch_splitting(
                  batch_contents,
                  unit_primitive: unit_primitive,
                  model: model,
                  user: user,
                  tracking_context: tracking_context
                )
              end

              embeddings
            end
          end
        end
      end
    end
  end
end

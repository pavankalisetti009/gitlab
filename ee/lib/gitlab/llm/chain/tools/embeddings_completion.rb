# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class EmbeddingsCompletion
          include ::Gitlab::Loggable
          include Langsmith::RunHelpers

          def initialize(current_user:, question:, logger: nil, tracking_context: {})
            @current_user = current_user
            @question = question
            @logger = logger || Gitlab::Llm::Logger.build
            @correlation_id = Labkit::Correlation::CorrelationId.current_id
            @tracking_context = tracking_context
          end

          def execute(&)
            return empty_response unless question.present?
            return empty_response unless ::Gitlab::Llm::TanukiBot.enabled_for?(user: current_user)

            search_documents = get_search_results(question)

            return empty_response if search_documents.blank?

            get_completions_ai_gateway(search_documents, &)
          end

          def get_search_results(question)
            response = Gitlab::Llm::AiGateway::DocsClient.new(current_user)
              .search(query: question) || {}

            response.dig('response', 'results')&.map(&:with_indifferent_access)
          end

          private

          attr_reader :current_user, :question, :logger, :correlation_id, :tracking_context

          def ai_gateway_request
            @ai_gateway_request ||= ::Gitlab::Llm::Chain::Requests::AiGateway.new(current_user,
              tracking_context: tracking_context)
          end

          def get_completions_ai_gateway(search_documents)
            final_prompt = Gitlab::Llm::Anthropic::Templates::TanukiBot
              .final_prompt(question: question, documents: search_documents)

            final_prompt_result = ai_gateway_request.request(
              { prompt: final_prompt[:prompt], options: final_prompt[:options] }
            ) do |data|
              yield data if block_given?
            end

            logger.info_or_debug(current_user,
              message: "Got Final Result", prompt: final_prompt[:prompt], response: final_prompt_result)

            Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot.new(
              { completion: final_prompt_result }.to_json,
              current_user,
              search_documents: search_documents
            )

          rescue Gitlab::Llm::AiGateway::Client::ConnectionError => error
            Gitlab::ErrorTracking.track_exception(error)

            logger.info(message: "Streaming error", error: error.message)
          end

          def empty_response
            Gitlab::Llm::ResponseModifiers::EmptyResponseModifier.new(
              s_("AI|I'm sorry, I couldn't find any documentation to answer your question."),
              error_code: empty_response_code
            )
          end

          def empty_response_code
            "M2000"
          end
        end
      end
    end
  end
end

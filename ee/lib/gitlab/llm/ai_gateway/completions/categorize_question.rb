# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class CategorizeQuestion < Base
          extend ::Gitlab::Utils::Override
          include Gitlab::Utils::StrongMemoize

          SCHEMA_URL = 'iglu:com.gitlab/ai_question_category/jsonschema/1-2-0'

          private_class_method def self.load_xml(filename)
            File.read(File.join(File.dirname(__FILE__), '..', '..', 'fixtures', filename)).tr("\n", '')
          end

          LLM_MATCHING_LABELS_XML = load_xml('labels.xml') # boolean attribute definitions

          REQUIRED_KEYS = %w[detailed_category category].freeze
          OPTIONAL_KEYS = (
            %w[language] +
              Hash.from_xml(LLM_MATCHING_LABELS_XML)
                  .dig('root', 'label').pluck('type') # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
          ).freeze
          PERMITTED_KEYS = REQUIRED_KEYS + OPTIONAL_KEYS

          override :inputs
          def inputs
            previous_message = messages[-2]
            previous_answer = previous_message&.assistant? ? previous_message.content : nil

            {
              question: options[:question],
              previous_answer: previous_answer
            }
          end

          private

          override :post_process
          def post_process(response)
            response = Gitlab::Json.parse(response)
            track(attributes(response)) ? '' : { 'detail' => 'Event not tracked' }
          end

          def attributes(response)
            # Turn array of matched label strings into boolean attributes
            labels = response.delete('labels')
            labels&.each { |label| response[label] = true }

            response.slice(*PERMITTED_KEYS).merge(Gitlab::Llm::ChatMessageAnalyzer.new(messages).execute)
          end

          def messages
            ::Gitlab::Llm::ChatStorage.new(user).messages_up_to(options[:message_id])
          end
          strong_memoize_attr :messages

          def track(attributes)
            return false if attributes.empty?

            unless contains_categories?(attributes)
              error_message = 'Response did not contain defined categories'
              log_error(message: error_message,
                event_name: 'error',
                ai_component: 'duo_chat')
              return false
            end

            context = SnowplowTracker::SelfDescribingJson.new(SCHEMA_URL, attributes)

            Gitlab::Tracking.event(
              self.class.to_s,
              "ai_question_category",
              context: [context],
              property: tracking_context[:request_id],
              user: user
            )
          end

          def contains_categories?(hash)
            REQUIRED_KEYS.each { |key| return false unless hash.has_key?(key) }
          end

          override :service_name
          def service_name
            :duo_chat
          end
        end
      end
    end
  end
end

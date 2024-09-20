# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module Logger
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          def log_conditional_info(user, message:, event_name:, ai_component:, **options)
            logger.conditional_info(user, message: message, klass: to_s, event_name: event_name,
              ai_component: ai_component, **options)
          end

          def log_info(message:, event_name:, ai_component:, **options)
            logger.info(message: message, event_name: event_name, klass: to_s, ai_component: ai_component, **options)
          end

          def log_error(message:, event_name:, ai_component:, **options)
            logger.error(message: message, event_name: event_name, klass: to_s, ai_component: ai_component, **options)
          end

          def logger
            Gitlab::Llm::Logger.build
          end
        end

        private

        def logger
          @logger ||= Gitlab::Llm::Logger.build
        end

        def log_conditional_info(user, message:, event_name:, ai_component:, **options)
          logger.conditional_info(user,
            message: message,
            klass: self.class.to_s,
            event_name: event_name,
            ai_component: ai_component,
            **options)
        end

        def log_info(message:, event_name:, ai_component:, **options)
          logger.info(message: message,
            klass: self.class.to_s,
            event_name: event_name,
            ai_component: ai_component,
                      **options)
        end

        def log_debug(message:, event_name:, ai_component:, **options)
          logger.debug(message: message,
            klass: self.class.to_s,
            event_name: event_name,
            ai_component: ai_component,
                       **options)
        end

        def log_error(message:, event_name:, ai_component:, **options)
          logger.error(message: message,
            klass: self.class.to_s,
            event_name: event_name,
            ai_component: ai_component,
                       **options)
        end

        def log_warn(message:, event_name:, ai_component:, **options)
          logger.warn(message: message,
            klass: self.class.to_s,
            event_name: event_name,
            ai_component: ai_component,
                       **options)
        end
      end
    end
  end
end

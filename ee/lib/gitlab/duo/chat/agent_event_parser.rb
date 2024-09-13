# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      class AgentEventParser
        def initialize(logger)
          @logger = logger
        end

        def parse(chunk)
          begin
            event = Gitlab::Json.parse(chunk)
          rescue JSON::ParserError
            # no-op
          end

          unless event && event['type'].present?
            logger.error(message: "Failed to parse a chunk from Duo Chat Agent", chunk: chunk)
            return
          end

          begin
            klass = "Gitlab::Duo::Chat::AgentEvents::#{event['type'].camelize}".constantize
            klass.new(event["data"])
          rescue NameError
            # Make sure that the v2/chat/agent endpoint in AI Gateway and the GitLab-Rails are compatible.
            logger.error(message: "Failed to find the event class in GitLab-Rails.", event_type: event['type'])
            nil
          end
        end

        attr_reader :logger
      end
    end
  end
end

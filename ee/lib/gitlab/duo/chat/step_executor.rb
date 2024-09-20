# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      class StepExecutor
        include Gitlab::Utils::StrongMemoize
        include Langsmith::RunHelpers

        DEFAULT_TIMEOUT = 60.seconds
        CHAT_V2_ENDPOINT = '/v2/chat/agent'

        ConnectionError = Class.new(StandardError)

        attr_reader :agent_steps

        def initialize(user)
          @user = user
          @logger = Gitlab::Llm::Logger.build
          @agent_steps = []
          @event_parser = AgentEventParser.new(logger)
        end

        def step(params)
          events = []

          params = update_params(params)

          # V2 Chat Agent in AI Gateway streams events as response, however,
          # Gitlab::HTTP_V2::BufferedIo (or Net::BufferedIo) splits the event further
          # per `BUFSIZE = 1024 * 16`, hence if the size of the event exceeds the buffer size,
          # it will yield incomplete event data.
          # Ref: https://github.com/ruby/net-protocol/blob/master/lib/net/protocol.rb#L214
          chunks_for_event = ""

          perform_agent_request(params) do |chunk|
            chunks_for_event += chunk
            event = event_parser.parse(chunks_for_event)

            next unless event

            chunks_for_event = ""

            logger.info_or_debug(user, message: "Received an event from v2/chat/agent", event: event)

            yield event if block_given?

            if event.instance_of? AgentEvents::Action
              step = {}
              step[:thought] = event.thought
              step[:tool] = event.tool
              step[:tool_input] = event.tool_input

              @agent_steps.append(step)
            end

            events.append(event)
          end

          events
        end
        traceable :step, name: 'Step forward Duo Chat Agent', run_type: 'chain'

        def update_observation(observation)
          if @agent_steps.empty?
            logger.error(message: "Failed to update observation")
            return
          end

          @agent_steps.last[:observation] = observation
        end

        private

        attr_reader :user, :logger, :event_parser

        def update_params(params)
          params.deep_merge(
            {
              options: {
                agent_scratchpad: {
                  agent_type: "react",
                  steps: @agent_steps
                }
              }
            }
          )
        end

        def perform_agent_request(params)
          logger.info_or_debug(user, message: "Request to v2/chat/agent", params: params)

          response = Gitlab::HTTP.post(
            "#{Gitlab::AiGateway.url}#{CHAT_V2_ENDPOINT}",
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: params.to_json,
            timeout: DEFAULT_TIMEOUT,
            allow_local_requests: true,
            stream_body: true
          ) do |fragment|
            yield fragment if block_given?
          end

          if response.success?
            logger.info_or_debug(user, message: "Finished streaming from v2/chat/agent")
            return
          end

          logger.error(message: "Received error from Duo Chat Agent", status: response.code)

          # TODO: Improve error handling
          raise Gitlab::AiGateway::ForbiddenError if response.forbidden?
          raise Gitlab::AiGateway::ClientError if response.code >= 400 && response.code < 500
          raise Gitlab::AiGateway::ServerError if response.code >= 500

          raise ConnectionError, 'AI gateway not reachable'
        end

        def service
          chat_feature_setting = ::Ai::FeatureSetting.find_by_feature(:duo_chat)
          feature_name = chat_feature_setting&.self_hosted? ? :self_hosted_models : :duo_chat

          ::CloudConnector::AvailableServices.find_by_name(feature_name)
        end
        strong_memoize_attr :service
      end
    end
  end
end

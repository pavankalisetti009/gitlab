# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Client # rubocop:disable Search/NamespacedClass
        include ::Gitlab::Loggable

        INDEXING_TIMEOUT_S = 30.minutes.to_i
        MAXIMUM_THREADS = 16
        CONTEXT_LINES_COUNT = 1
        PROXY_SEARCH_PATH = '/webserver/api/v2/search'

        TooManyRequestsError = Class.new(StandardError)

        class << self
          def instance
            @instance ||= new
          end

          delegate :search, :search_multi_node, :index, to: :instance
        end

        def search(query, num:, project_ids:, node_id:, search_mode:)
          start = Time.current

          # Safety net because Zoekt will match all projects if you provide
          # an empty array.
          raise 'Not possible to search without at least one project specified' if project_ids.blank?
          raise 'Global search is not supported' if project_ids == :any

          payload = build_search_payload(query, num: num, search_mode: search_mode, project_ids: project_ids)

          path = '/api/search'
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          response = post_request(join_url(target_node.search_base_url, path), payload)

          log_error('Zoekt search failed', status: response.code, response: response.body) unless response.success?

          Gitlab::Search::Zoekt::Response.new parse_response(response)
        ensure
          add_request_details(start_time: start, path: path, body: payload)
        end

        def search_multi_node(query, num:, targets:, search_mode:, use_proxy: false)
          return search_zoekt_proxy(query, num: num, targets: targets, search_mode: search_mode) if use_proxy

          if targets.size > MAXIMUM_THREADS
            raise ArgumentError, "Too many targets #{targets.size}, maximum allowed #{MAXIMUM_THREADS}"
          end

          threads = targets.map do |node_id, project_ids|
            Thread.new do
              response = search(query, num: num, project_ids: project_ids, node_id: node_id, search_mode: search_mode)
              [node_id, response]
            end
          end

          Gitlab::Search::Zoekt::MultiNodeResponse.new threads.each(&:join).map(&:value).to_h
        end

        def search_zoekt_proxy(query, num:, targets:, search_mode:)
          start = Time.current
          payload = build_search_payload(query, num: num, search_mode: search_mode)
          payload[:ForwardTo] = targets.map do |node_id, project_ids|
            target_node = node(node_id)
            { Endpoint: target_node.search_base_url, RepoIds: project_ids }
          end

          # Unless a node is specified, prefer the node with the most projects
          node_id ||= targets.max_by { |_zkt_node_id, project_ids| project_ids.length }.first
          proxy_node = node(node_id)
          raise 'Node can not be found' unless proxy_node

          search_url = join_url(proxy_node.search_base_url, PROXY_SEARCH_PATH)
          response = post_request(search_url, payload, timeout: INDEXING_TIMEOUT_S)
          log_error('Zoekt search failed', status: response.code, response: response.body) unless response.success?
          Gitlab::Search::Zoekt::Response.new parse_response(response)
        ensure
          add_request_details(start_time: start, path: PROXY_SEARCH_PATH, body: payload)
        end

        private

        def post_request(url, payload = {}, **options)
          defaults = {
            headers: { 'Content-Type' => 'application/json' },
            body: payload.to_json,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.post(
            url,
            defaults.merge(options)
          )
        rescue *Gitlab::HTTP::HTTP_ERRORS => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def delete_request(url, **options)
          defaults = {
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.delete(
            url,
            defaults.merge(options)
          )
        rescue *Gitlab::HTTP::HTTP_ERRORS => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def basic_auth_params
          @basic_auth_params ||= {
            username: username,
            password: password
          }.compact
        end

        def build_search_payload(query, num:, search_mode:, project_ids: nil)
          {
            Q: format_query(query, search_mode: search_mode),
            Opts: {
              TotalMaxMatchCount: num,
              NumContextLines: CONTEXT_LINES_COUNT
            }
          }.tap do |payload|
            payload[:RepoIds] = project_ids if project_ids.present?
          end
        end

        def node(node_id)
          ::Search::Zoekt::Node.find_by_id(node_id)
        end

        def join_url(base_url, path)
          # We can't use URI.join because it doesn't work properly with something like
          # URI.join('http://example.com/api', 'index') => #<URI::HTTP http://example.com/index>
          url = [base_url, path].join('/')
          url.gsub(%r{(?<!:)/+}, '/') # Remove duplicate slashes
        end

        def parse_response(response)
          ::Gitlab::Json.parse(response.body).with_indifferent_access
        rescue Gitlab::Json.parser_error => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def add_request_details(start_time:, path:, body:)
          return unless ::Gitlab::SafeRequestStore.active?

          duration = (Time.current - start_time)

          ::Gitlab::Instrumentation::Zoekt.increment_request_count
          ::Gitlab::Instrumentation::Zoekt.add_duration(duration)

          ::Gitlab::Instrumentation::Zoekt.add_call_details(
            duration: duration,
            method: 'POST',
            path: path,
            body: body
          )
        end

        def username
          @username ||= File.exist?(username_file) ? File.read(username_file).chomp : nil
        end

        def password
          @password ||= File.exist?(password_file) ? File.read(password_file).chomp : nil
        end

        def username_file
          Gitlab.config.zoekt.username_file
        end

        def password_file
          Gitlab.config.zoekt.password_file
        end

        def logger
          @logger ||= ::Search::Zoekt::Logger.build
        end

        def log_error(message, payload = {})
          logger.error(build_structured_payload(**payload.merge(message: message)))
        end

        def format_query(query, search_mode:)
          case search_mode.to_sym
          when :exact
            ::Search::Zoekt::Query.new(query).exact_search_query
          when :regex
            query
          else
            raise ArgumentError, 'Not a valid search_mode'
          end
        end
      end
    end
  end
end

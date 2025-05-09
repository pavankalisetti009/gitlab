# frozen_string_literal: true

require 'socket'
require 'fileutils'
require 'timeout'
require 'uri'

module Search
  module Zoekt
    # This class is responsible for starting and stopping Zoekt processes during test runs
    #
    # By default, this class will start local Zoekt indexer and webserver processes using
    # the compiled binary in tmp/tests/gitlab-zoekt/bin/gitlab-zoekt.
    #
    # If you want to use external Zoekt services (e.g., running in Docker or on another machine),
    # you can set the following environment variables:
    #
    # - ZOEKT_INDEX_BASE_URL: URL of the Zoekt indexer service (default: http://127.0.0.1:6060)
    # - ZOEKT_SEARCH_BASE_URL: URL of the Zoekt webserver service (default: http://127.0.0.1:6070)
    #
    # When these environment variables are set, the process manager will not start local
    # processes and will use the provided URLs instead.
    class ZoektProcessManager
      ZOEKT_INDEX_PORT = 6060
      ZOEKT_SEARCH_PORT = 6070
      INDEX_DIR = Rails.root.join("tmp/tests/zoekt-index").to_s
      LOG_DIR = Rails.root.join("tmp/tests/zoekt-logs").to_s

      def self.instance
        @instance ||= new
      end

      def self.custom_urls_provided?
        ENV.key?('ZOEKT_INDEX_BASE_URL') || ENV.key?('ZOEKT_SEARCH_BASE_URL')
      end

      def initialize
        @indexer_pid = nil
        @webserver_pid = nil
        @index_base_url = ENV.fetch('ZOEKT_INDEX_BASE_URL', "http://127.0.0.1:#{ZOEKT_INDEX_PORT}")
        @search_base_url = ENV.fetch('ZOEKT_SEARCH_BASE_URL', "http://127.0.0.1:#{ZOEKT_SEARCH_PORT}")
        @using_custom_urls = self.class.custom_urls_provided?

        # Create index directory if it doesn't exist
        FileUtils.mkdir_p(INDEX_DIR)
        # Create log directory if it doesn't exist
        FileUtils.mkdir_p(LOG_DIR)
      end

      def start
        # If custom URLs are provided, don't start local processes
        return if @using_custom_urls

        # Return if processes are already running
        return if @indexer_pid && @webserver_pid && process_running?(@indexer_pid) && process_running?(@webserver_pid)

        stop if @indexer_pid || @webserver_pid

        zoekt_binary = Search::Zoekt.bin_path
        # Create a test secret if it doesn't exist
        secret_dir = Rails.root.join("tmp/tests").to_s
        secret_path = File.join(secret_dir, '.gitlab_shell_secret')
        unless File.exist?(secret_path)
          FileUtils.mkdir_p(secret_dir)
          File.write(secret_path, SecureRandom.hex(32))
        end

        # Create log files for stdout and stderr
        indexer_log = File.join(LOG_DIR, "indexer.log")
        webserver_log = File.join(LOG_DIR, "webserver.log")

        # Start indexer process
        @indexer_pid = spawn(
          zoekt_binary,
          'indexer',
          "-index_dir", INDEX_DIR,
          "-listen", ":#{ZOEKT_INDEX_PORT}",
          "-secret_path", secret_path,
          out: indexer_log,
          err: indexer_log
        )

        # Start webserver process
        @webserver_pid = spawn(
          zoekt_binary,
          'webserver',
          "-index_dir", INDEX_DIR,
          "-rpc",
          "-listen", ":#{ZOEKT_SEARCH_PORT}",
          "-secret_path", secret_path,
          out: webserver_log,
          err: webserver_log
        )

        # Wait for processes to start
        wait_for_services

        # Register process termination on exit
        at_exit { stop }
      end

      def stop
        # If custom URLs are provided, don't stop any processes
        return if @using_custom_urls

        # Kill processes if they exist
        Process.kill("TERM", @indexer_pid) if @indexer_pid && process_running?(@indexer_pid)
        Process.kill("TERM", @webserver_pid) if @webserver_pid && process_running?(@webserver_pid)

        # Reset PIDs
        @indexer_pid = nil
        @webserver_pid = nil
      rescue Errno::ESRCH
        # Process not found, which is fine
      end

      def process_running?(pid)
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end

      def wait_for_services
        if @using_custom_urls
          # If using custom URLs, verify they are reachable
          verify_custom_urls_connectivity
        else
          # Wait for indexer to start accepting connections
          wait_for_port(ZOEKT_INDEX_PORT)

          # Wait for webserver to start accepting connections
          wait_for_port(ZOEKT_SEARCH_PORT)
        end
      end

      def verify_custom_urls_connectivity
        # Extract host and port from URLs
        index_uri = URI.parse(@index_base_url)
        search_uri = URI.parse(@search_base_url)

        # Check if the services are reachable
        begin
          Timeout.timeout(5) do
            index_socket = TCPSocket.new(index_uri.host, index_uri.port)
            index_socket.close

            search_socket = TCPSocket.new(search_uri.host, search_uri.port)
            search_socket.close
          end
        rescue StandardError => e
          Rails.logger.warn "Warning: Unable to connect to custom Zoekt services: #{e.message}"
          Rails.logger.warn "Ensure your ZOEKT_INDEX_BASE_URL (#{@index_base_url}) and " \
            "ZOEKT_SEARCH_BASE_URL (#{@search_base_url}) are correct"
        end
      end

      def wait_for_port(port, max_retries = 100, retry_delay = 0.2)
        retries = 0
        begin
          socket = TCPSocket.new('127.0.0.1', port)
          socket.close
          true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          retries += 1
          if retries <= max_retries
            sleep(retry_delay)
            retry
          else
            false
          end
        end
      end

      attr_reader :index_base_url, :search_base_url
    end
  end
end

# frozen_string_literal: true

module Search
  module Zoekt
    class HealthService
      def self.execute(...)
        new(...).execute
      end

      def initialize(logger:, options: {})
        @logger = logger
        @options = options
      end

      def execute
        logger.info(Rainbow("=== Zoekt Health Check ===").bright.cyan)
        logger.info("")

        # Run Node Status Check
        logger.info(Rainbow("Node Status:").bright.yellow)
        node_result = HealthCheck::NodeStatusService.execute(logger: logger)

        logger.info("")

        # Run Configuration Check
        logger.info(Rainbow("Configuration:").bright.yellow)
        configuration_result = HealthCheck::ConfigurationService.execute(logger: logger)

        logger.info("")

        # Run Connectivity Check
        logger.info(Rainbow("Connectivity:").bright.yellow)
        connectivity_result = HealthCheck::ConnectivityService.execute(logger: logger)

        logger.info("")

        # Display overall status with appropriate color
        overall_status = determine_overall_status([node_result, configuration_result, connectivity_result])
        status_color = status_color_for(overall_status)

        logger.info(
          "#{Rainbow('Overall Status:').bright.yellow} #{Rainbow(overall_status.to_s.upcase).color(status_color)}"
        )

        # Display recommendations if there are any issues
        display_recommendations([node_result, configuration_result, connectivity_result])

        # Set exit code for automation/monitoring (only when not in watch mode)
        exit_code = case overall_status
                    when :healthy
                      0
                    when :degraded
                      1
                    when :unhealthy
                      2
                    end

        # Only exit with non-zero code if not in watch mode
        # Watch mode is detected by checking if we're in a loop (options would contain watch_interval)
        should_exit = exit_code > 0 && !options.key?(:watch_mode)
        exit(exit_code) if should_exit

        exit_code
      end

      private

      attr_reader :logger, :options

      def determine_overall_status(results)
        return :unhealthy if results.any? { |result| result[:status] == :unhealthy }
        return :degraded if results.any? { |result| result[:status] == :degraded }

        :healthy
      end

      def status_color_for(status)
        case status
        when :healthy
          :green
        when :degraded
          :yellow
        when :unhealthy
          :red
        else
          :white
        end
      end

      def display_recommendations(results)
        all_errors = results.flat_map { |result| result[:errors] }
        all_warnings = results.flat_map { |result| result[:warnings] }

        return if all_errors.empty? && all_warnings.empty?

        logger.info("")
        logger.info(Rainbow("Recommendations:").bright.yellow)

        all_errors.each do |error|
          logger.info("  #{Rainbow('•').red} #{error}")
        end

        all_warnings.each do |warning|
          logger.info("  #{Rainbow('•').yellow} #{warning}")
        end
      end
    end
  end
end

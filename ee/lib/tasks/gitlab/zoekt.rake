# frozen_string_literal: true

namespace :gitlab do
  namespace :zoekt do
    desc 'GitLab | Zoekt | List information about Exact Code Search integration'
    task :info, [:watch_interval] => :environment do |t, args|
      run_with_interval(name: t.name, watch_interval: args[:watch_interval]) do
        task_executor_service.execute(:info)
      end
    end

    def run_with_interval(name:, watch_interval:)
      interval = watch_interval.to_f
      return yield if interval <= 0

      trap('INT') do
        puts "\nInterrupted. Exiting gracefully..."
        exit
      end

      loop do
        clear_screen
        stdout_logger.info "Every #{interval}s: #{name} (Updated: #{Time.now.utc.iso8601})"

        yield
        sleep interval
      end
    end

    def clear_screen
      system('clear') || system('cls') # Clear screen (Linux/macOS & Windows)
    end

    def task_executor_service
      Search::Zoekt::RakeTaskExecutorService.new(logger: stdout_logger)
    end

    def stdout_logger
      @stdout_logger ||= Logger.new($stdout).tap do |l|
        l.formatter = ->(_severity, _datetime, _progname, msg) { "#{msg}\n" }
      end
    end
  end
end

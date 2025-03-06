# frozen_string_literal: true

namespace :gitlab do
  namespace :zoekt do
    desc 'GitLab | Zoekt | List information about Exact Code Search integration'
    task info: :environment do
      task_executor_service.execute(:info)
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

# frozen_string_literal: true

namespace :gitlab do
  namespace :zoekt do
    desc 'GitLab | Zoekt | List information about Exact Code Search integration'
    task :info, [:watch_interval] => :environment do |t, args|
      Search::RakeTask::Zoekt.info(name: t.name, watch_interval: args[:watch_interval])
    end
  end
end

# frozen_string_literal: true

namespace :gitlab do
  namespace :zoekt do
    desc 'GitLab | Zoekt | List information about Exact Code Search integration'
    task :info, [:watch_interval, :extended] => :environment do |t, args|
      Search::RakeTask::Zoekt.info(
        name: t.name,
        extended: args[:extended],
        watch_interval: args[:watch_interval]
      )
    end
  end
end

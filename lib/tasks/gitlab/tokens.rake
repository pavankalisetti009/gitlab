# frozen_string_literal: true

module Tasks
  module Gitlab
    module Tokens
      TOTAL_WIDTH = 70

      class << self
        def analyze
          show_pat_expires_at_migration_status
          show_most_common_pat_expiration_dates
        end

        def show_pat_expires_at_migration_status
          sql = <<~SQL
            SELECT * FROM batched_background_migrations
            WHERE job_class_name = 'CleanupPersonalAccessTokensWithNilExpiresAt'
          SQL

          print_header("Personal Access Token Migration Status")

          record = ApplicationRecord.connection.select_one(sql)

          if record
            puts "Started at: #{record['started_at']}"
            puts "Finished  : #{record['finished_at']}"
          else
            puts "Status: Not run"
          end

          print_footer
        end

        def show_most_common_pat_expiration_dates
          print_header "Top 10 Personal Access Token Expiration Dates"

          puts "| Expiration Date | Count |"
          puts "|-----------------|-------|"

          PersonalAccessToken
            .select(:expires_at, Arel.sql('count(*)'))
            .where('expires_at >= NOW()')
            .group(:expires_at)
            .order(Arel.sql('count(*) DESC'))
            .order(expires_at: :desc)
            .limit(10)
            .each do |row|
            puts "| #{row[:expires_at].to_s.ljust(15)} | #{row[:count].to_s.ljust(5)} |"
          end

          print_footer
        end

        def print_header(title, total_width = TOTAL_WIDTH)
          title_length = title.length
          side_length = (total_width - title_length) / 2

          left_side = "=" * side_length
          right_side = "=" * (side_length + (total_width % 2))

          header = "#{left_side} #{title} #{right_side}"
          puts header
        end

        def print_footer
          # Account for the spaces between the "=" in the header
          puts "=" * (TOTAL_WIDTH + 2)
        end
      end
    end
  end
end

namespace :gitlab do
  namespace :tokens do
    desc 'GitLab | Tokens | Show information about tokens'
    task analyze: :environment do |_t, _args|
      Tasks::Gitlab::Tokens.analyze
    end
  end
end

# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Response # rubocop:disable Search/NamespacedClass -- we want to have this class in the same namespace as the client
        attr_reader :parsed_response, :current_user

        def self.empty
          new({
            Result: {
              FileCount: 0,
              FileMatchCount: 0,
              LineMatchCount: 0,
              MatchCount: 0,
              NgramMatches: 0,
              TotalFileMatchCount: 0,
              TotalLineMatchCount: 0
            }
          })
        end

        def initialize(response, current_user: nil)
          @parsed_response = response.with_indifferent_access
          @current_user = current_user
        end

        def success?
          error_message.nil?
        end

        def failure?
          error_message.present?
        end

        def error_message
          parsed_response[:Error] || parsed_response[:error]
        end

        def result
          parsed_response[:Result]
        end

        def file_count
          return result[:FileMatchCount] if result[:FileMatchCount].present?

          @file_count ||= result['Files']&.count.to_i
        end

        def match_count
          return result[:LineMatchCount] if result[:LineMatchCount].present?

          @match_count ||= (result['Files']&.sum { |x| x['LineMatches']&.count }).to_i
        end

        def each_file
          files = result[:Files] || []

          files.each do |file|
            yield file
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Search
  module Zoekt
    class Params
      UNLIMITED = 0

      def initialize(options)
        @options = options
      end

      def max_file_match_window
        UNLIMITED
      end

      def max_file_match_results
        multi_match? ? search_limit : UNLIMITED
      end

      def max_line_match_window
        ::Search::Zoekt::SearchResults::ZOEKT_COUNT_LIMIT
      end

      def max_line_match_results
        multi_match? ? UNLIMITED : search_limit
      end

      def max_line_match_results_per_file
        multi_match? ? options[:multi_match].max_chunks_size : MultiMatch::MAX_CHUNKS_PER_FILE
      end

      private

      attr_reader :options

      def search_limit
        options.fetch(:limit)
      end

      def multi_match?
        options[:multi_match].present?
      end
    end
  end
end

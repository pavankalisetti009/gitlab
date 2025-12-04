# frozen_string_literal: true

module Ai
  module ActiveContext
    class ConnectionService
      ConnectionError = Class.new(StandardError)

      def self.connect_to_advanced_search_cluster
        name = if ::Gitlab::Elastic::Helper.default.matching_distribution?(:opensearch)
                 :opensearch
               elsif ::Gitlab::Elastic::Helper.default.matching_distribution?(:elasticsearch)
                 :elasticsearch
               else
                 raise ConnectionError, 'Connection invalid'
               end

        adapter_class = Ai::ActiveContext::Connection::ADAPTERS_FOR_ADVANCED_SEARCH[name]

        connection = Ai::ActiveContext::Connection.create!(
          name: name.to_s,
          adapter_class: adapter_class.to_s,
          options: { use_advanced_search_config: true }
        )
        connection.activate!
      end
    end
  end
end

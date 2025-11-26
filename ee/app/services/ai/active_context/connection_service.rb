# frozen_string_literal: true

module Ai
  module ActiveContext
    class ConnectionService
      def self.connect_to_advanced_search_cluster
        name = if ApplicationSetting.current.elasticsearch_aws
                 :opensearch
               else
                 :elasticsearch
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

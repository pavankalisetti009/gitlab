# frozen_string_literal: true

module Search
  module Zoekt
    class LoadBalancer
      CACHE_EXPIRY = 300

      def self.distribution(nodes = nil)
        nodes ||= Node.online
        new(nodes).distribution
      end

      attr_reader :nodes

      def initialize(nodes)
        raise ArgumentError, 'no nodes available for zoekt load balancer' if nodes.empty?

        @nodes = nodes
      end

      def distribution
        with_redis do |redis|
          nodes.map do |node|
            {
              node_id: node.id,
              current_load: redis.get(node_key(node)).to_f
            }
          end
        end
      end

      def reset!
        with_redis do |redis|
          nodes.each do |node|
            redis.del(node_key(node))
          end
        end
      end

      def pick
        return if nodes.empty?
        return nodes.first if nodes.size == 1

        with_redis do |redis|
          # Select node with lowest load
          nodes.min_by { |node| redis.get(node_key(node)).to_f }
        end
      end

      def increase_load(node, weight: 1)
        # Increase by weight (heavy queries count more)
        with_redis do |redis|
          redis.multi do |r|
            r.incrbyfloat(node_key(node), weight)
            r.expire(node_key(node), CACHE_EXPIRY) # Set expiry to avoid orphans
          end
        end
      end

      def decrease_load(node, weight: 1)
        # Reduce load when query completes
        with_redis do |redis|
          new_value = redis.incrbyfloat(node_key(node), -weight)

          # Clean up if load goes to 0 or negative (due to floating point or errors)
          redis.del(node_key(node)) if new_value <= 0
        end
      end

      private

      def node_key(node)
        "node:#{node.id}:load"
      end

      def with_redis(&block)
        Gitlab::Redis::Cache.with(&block) # rubocop:disable CodeReuse/ActiveRecord -- N/A
      end
    end
  end
end

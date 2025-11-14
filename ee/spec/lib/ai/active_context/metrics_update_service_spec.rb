# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ActiveContext::MetricsUpdateService, :prometheus, feature_category: :global_search do
  describe '#execute' do
    it 'sets gauges' do
      gauge_double = instance_double(Prometheus::Client::Gauge)

      queue_counts = [
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 0, count: 4 },
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 1, count: 0 },
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 2, count: 2 }
      ]

      allow(::ActiveContext::Queues).to receive(:queue_counts).and_return(queue_counts)

      allow(Gitlab::Metrics).to receive(:gauge).and_return(gauge_double)

      expect(gauge_double).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 0 }, 4)
      expect(gauge_double).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 1 }, 0)
      expect(gauge_double).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 2 }, 2)

      described_class.new.execute
    end
  end
end

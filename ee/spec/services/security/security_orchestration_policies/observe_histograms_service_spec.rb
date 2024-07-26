# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ObserveHistogramsService, feature_category: :security_policy_management do
  let(:name) { :gitlab_security_policies_scan_execution_configuration_rendering_seconds }
  let(:histogram) { described_class.histogram(name) }

  describe '.histogram' do
    let(:description) { described_class::HISTOGRAMS.dig(name, :description) }
    let(:buckets) { described_class::HISTOGRAMS.dig(name, :buckets) }

    it 'returns the expected histogram', :aggregate_failures do
      expect(histogram.name).to be(name)
      expect(histogram.docstring).to eq(description)
      expect(histogram.instance_variable_get(:@buckets)).to eq(buckets)
    end
  end

  describe '.measure' do
    let(:labels) { { foo: "bar" } }
    let(:return_value) { Object.new }

    subject(:measure) { described_class.measure(name, **labels) { return_value } }

    before do
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).twice.and_return(1, 2)
    end

    it 'observes' do
      expect(histogram).to receive(:observe).with(labels, 1.0)

      measure
    end

    it 'returns the block return value' do
      allow(histogram).to receive(:observe).with(labels, 1.0)
      expect(measure).to be(return_value)
    end
  end
end

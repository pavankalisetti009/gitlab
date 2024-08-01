# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::BaseProbe, feature_category: :cloud_connector do
  subject(:test_probe) { test_probe_class.new }

  before do
    stub_const('TestProbe', test_probe_class)
  end

  describe '#execute' do
    context 'when not implemented in subclass' do
      let(:test_probe_class) { Class.new(described_class) }

      it 'raises an error' do
        expect { test_probe.execute }.to raise_error(RuntimeError, "TestProbe must implement #execute")
      end
    end

    context 'when implemented in subclass' do
      let(:test_probe_class) do
        Class.new(described_class) do
          def execute(*); end
        end
      end

      it 'does not raise an error' do
        expect { test_probe.execute }.not_to raise_error
      end
    end
  end

  describe '#success' do
    let(:test_probe_class) do
      Class.new(described_class) do
        def execute(*)
          success('Test success message')
        end
      end
    end

    it 'returns a successful ProbeResult' do
      result = test_probe.execute

      expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
      expect(result.success).to be true
      expect(result.name).to eq(:test_probe)
    end
  end

  describe '#failure' do
    let(:test_probe_class) do
      Class.new(described_class) do
        def execute(*)
          failure('Test failure message')
        end
      end
    end

    it 'returns a failed ProbeResult' do
      result = test_probe.execute

      expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
      expect(result.success).to be false
      expect(result.name).to eq(:test_probe)
    end
  end
end

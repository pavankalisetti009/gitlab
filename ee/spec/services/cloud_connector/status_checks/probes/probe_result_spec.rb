# frozen_string_literal: true

require 'fast_spec_helper'
require_relative "../../../../../app/services/cloud_connector/status_checks/probes/probe_result"

RSpec.describe CloudConnector::StatusChecks::Probes::ProbeResult, feature_category: :cloud_connector do
  let(:name) { 'Test Probe' }
  let(:success) { true }
  let(:message) { 'Probe successful' }
  let(:probe_result) { described_class.new(name, success, message) }

  describe '#success?' do
    context 'when success is true' do
      it 'returns true' do
        expect(probe_result.success?).to be true
      end
    end

    context 'when success is false' do
      let(:success) { false }

      it 'returns false' do
        expect(probe_result.success?).to be false
      end
    end

    context 'when success is nil' do
      let(:success) { nil }

      it 'returns false' do
        expect(probe_result.success?).to be false
      end
    end
  end

  describe 'attribute readers' do
    it 'allows reading of name attribute' do
      expect(probe_result.name).to eq(name)
    end

    it 'allows reading of success attribute' do
      expect(probe_result.success).to eq(success)
    end

    it 'allows reading of message attribute' do
      expect(probe_result.message).to eq(message)
    end
  end
end

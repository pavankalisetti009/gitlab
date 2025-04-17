# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineAnalyzersStatusUpdateWorker, feature_category: :security_asset_inventories do
  let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
  let_it_be(:pipeline) { sast_scan.pipeline }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(pipeline.id) }

    let(:analyzer_status_service) { instance_double(Security::AnalyzersStatusUpdateService) }

    before do
      allow(Security::AnalyzersStatusUpdateService).to receive(:new).with(pipeline).and_return(analyzer_status_service)
      allow(analyzer_status_service).to receive(:execute)
    end

    describe 'when no such pipeline exists' do
      it 'does not call `Security::AnalyzerStatusUpdateService`' do
        described_class.new.perform(-1)

        expect(Security::AnalyzersStatusUpdateService).not_to have_received(:new)
      end
    end

    describe 'when security_dashboard feature is not available' do
      it 'does not call `Security::AnalyzerStatusUpdateService`' do
        run_worker

        expect(Security::AnalyzersStatusUpdateService).not_to have_received(:new)
      end
    end

    describe 'when security_dashboard feature is available' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      it 'calls `Security::AnalyzerStatusUpdateService`' do
        run_worker

        expect(Security::AnalyzersStatusUpdateService).to have_received(:new).with(pipeline)
        expect(analyzer_status_service).to have_received(:execute)
      end
    end
  end
end

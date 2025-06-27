# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportService, feature_category: :dependency_management do
  let_it_be(:num_components) { 283 }
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:sbom_report) { create(:ci_reports_sbom_report, num_components: num_components) }

  let(:sequencer) { ::Ingestion::Sequencer.new }
  let(:source_sequencer) { ::Ingestion::Sequencer.new(start: num_components + 1) }

  subject(:execute) { described_class.execute(pipeline, sbom_report) }

  describe '#execute' do
    before do
      allow(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .and_wrap_original do |_, _, occurrence_maps|
        {
          occurrence_ids: occurrence_maps.map { sequencer.next },
          source_ids: occurrence_maps.map { source_sequencer.next }
        }
      end
    end

    it 'executes IngestReportSliceService in batches' do
      full_batches, remainder = num_components.divmod(described_class::BATCH_SIZE)

      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: described_class::BATCH_SIZE)).exactly(full_batches).times
      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: remainder)).once

      result = execute
      all_occurrence_ids = result.flat_map { |batch| batch[:occurrence_ids] }
      all_source_ids = result.flat_map { |batch| batch[:source_ids] }

      expect(all_occurrence_ids).to match_array(sequencer.range)
      expect(all_source_ids).to match_array(source_sequencer.range)
    end

    it 'enqueues Sbom::BuildDependencyGraphWorker' do
      expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(pipeline.project_id)

      execute
    end

    context 'when dependency_paths feature flag is disabled' do
      before do
        stub_feature_flags(dependency_paths: false)
      end

      it 'does not enqueue any jobs' do
        expect(::Sbom::BuildDependencyGraphWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when the same report is ingested again' do
      let(:graph_cache_key) { instance_double(Sbom::Ingestion::DependencyGraphCacheKey, key: "key_value") }

      it 'only generates the graph once' do
        expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(pipeline.project_id).once
        allow(Sbom::Ingestion::DependencyGraphCacheKey)
          .to receive(:new)
          .with(pipeline.project, sbom_report)
          .and_return(graph_cache_key)

        expect(Rails.cache)
          .to receive(:write)
          .with("key_value", { pipeline_id: pipeline.id }, expires_in: 24.hours)
          .once

        execute
        execute
      end
    end

    context 'when two different reports are ingested' do
      let_it_be(:pipeline_2) { build_stubbed(:ci_pipeline) }
      let_it_be(:sbom_report_2) { create(:ci_reports_sbom_report, num_components: num_components + 1) }

      let(:graph_cache_key_1) { instance_double(Sbom::Ingestion::DependencyGraphCacheKey, key: "key_value_1") }
      let(:graph_cache_key_2) { instance_double(Sbom::Ingestion::DependencyGraphCacheKey, key: "key_value_2") }

      it 'builds the graph once for each report' do
        expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(pipeline.project_id).once
        allow(Sbom::Ingestion::DependencyGraphCacheKey)
          .to receive(:new)
          .with(pipeline.project, sbom_report)
          .and_return(graph_cache_key_1)
        expect(Rails.cache)
          .to receive(:write)
          .with("key_value_1", { pipeline_id: pipeline.id }, expires_in: 24.hours)
          .once

        expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(pipeline_2.project_id).once
        allow(Sbom::Ingestion::DependencyGraphCacheKey)
          .to receive(:new)
          .with(pipeline_2.project, sbom_report_2)
          .and_return(graph_cache_key_2)
        expect(Rails.cache)
          .to receive(:write)
          .with("key_value_2", { pipeline_id: pipeline_2.id }, expires_in: 24.hours)
          .once

        described_class.execute(pipeline, sbom_report)
        described_class.execute(pipeline_2, sbom_report_2)
      end
    end
  end
end

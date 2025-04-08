# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::UpdateTokenStatusWorker, feature_category: :secret_detection do
  describe '#perform' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline) }

    subject(:worker) { described_class.new }

    shared_examples 'creates a finding token status' do |expected_status|
      it "creates FindingTokenStatus with \"#{expected_status}\" status" do
        expect { worker.perform(pipeline.id) }.to change { Vulnerabilities::FindingTokenStatus.count }.by(1)

        finding.reload
        expect(finding.finding_token_status).to be_present
        expect(finding.finding_token_status.status).to eq(expected_status)
      end
    end

    context 'when validity checks FF is disabled' do
      before do
        stub_feature_flags(validity_checks: false)
      end

      it 'does not run' do
        expect { worker.perform(pipeline.id) }.not_to change { Vulnerabilities::FindingTokenStatus.count }
      end
    end

    context 'when validity checks FF is enabled' do
      before do
        stub_feature_flags(validity_checks: true)
      end

      context 'when there are no findings' do
        let(:empty_batch) { Vulnerabilities::Finding.none }

        it 'does not process empty batches' do
          allow(worker).to receive(:build_token_status_attributes_by_token_sha).and_call_original

          worker.send(:process_findings_batch, empty_batch)

          expect(worker).not_to have_received(:build_token_status_attributes_by_token_sha)
        end
      end

      context 'when finding exists with no token' do
        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata.delete('raw_source_code_extract')
          finding.update!(raw_metadata: parsed_metadata.to_json)
        end

        it_behaves_like 'creates a finding token status', 'unknown'
      end

      describe 'when a token is not found' do
        it_behaves_like 'creates a finding token status', 'unknown'
      end

      context 'when multiple findings have the same token' do
        let(:second_finding) { create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline) }
        let(:third_finding) { create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline) }

        let(:token_value) { 'same_token_value' }
        let(:token_sha) { Gitlab::CryptoHelper.sha256(token_value) }
        let(:mock_token) { instance_double(PersonalAccessToken, active?: true, token_digest: token_sha) }

        before do
          # Set the same token value in all three findings
          [finding, second_finding, third_finding].each do |f|
            parsed_metadata = ::Gitlab::Json.parse(f.raw_metadata)
            parsed_metadata['raw_source_code_extract'] = token_value
            f.update!(raw_metadata: parsed_metadata.to_json)
          end

          allow(PersonalAccessToken).to receive(:with_token_digests).and_return([mock_token])
        end

        it 'creates token status for all findings with the same token' do
          expect { worker.perform(pipeline.id) }.to change { Vulnerabilities::FindingTokenStatus.count }.by(3)

          [finding, second_finding, third_finding].each do |f|
            f.reload
            expect(f.finding_token_status).to be_present
            expect(f.finding_token_status.status).to eq('active')
          end
        end
      end

      context 'when upsert fails' do
        before do
          allow(Vulnerabilities::FindingTokenStatus)
            .to receive(:upsert_all).and_raise(ActiveRecord::StatementInvalid.new("test exception"))
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
          allow(Gitlab::AppLogger).to receive(:error)
        end

        it 'tracks the exception and logs an error' do
          expect { worker.perform(pipeline.id) }.to raise_error(ActiveRecord::StatementInvalid)
          expect(Gitlab::ErrorTracking).to have_received(:track_exception)
          expect(Gitlab::AppLogger).to have_received(:error)
        end
      end

      describe 'when token is found' do
        let(:mock_token) do
          token_value = finding.metadata['raw_source_code_extract']
          token_sha = Gitlab::CryptoHelper.sha256(token_value)
          instance_double(PersonalAccessToken, active?: active, token_digest: token_sha)
        end

        before do
          allow(PersonalAccessToken).to receive(:with_token_digests).and_return([mock_token])
        end

        describe 'when a token is active' do
          let(:active) { true }

          it_behaves_like 'creates a finding token status', 'active'
        end

        describe 'when a token is inactive' do
          let(:active) { false }

          describe 'when finding has no status' do
            it_behaves_like 'creates a finding token status', 'inactive'
          end

          describe 'when finding has a status of active' do
            before do
              create(:finding_token_status, status: 'active', finding: finding)
            end

            it 'updates existing finding token status to inactive' do
              original_created_at = Vulnerabilities::FindingTokenStatus.first.created_at
              expect(Vulnerabilities::FindingTokenStatus.count).to eq(1)
              expect(finding.reload.finding_token_status.status).to eq('active')
              expect { worker.perform(pipeline.id) }.not_to change { Vulnerabilities::FindingTokenStatus.count }
              finding.reload

              expect(finding.finding_token_status.created_at).to eq(original_created_at)
              expect(finding.finding_token_status.status).to eq('inactive')
            end
          end
        end
      end

      context 'when processing multiple findings' do
        let_it_be(:many_findings) do
          create_list(:vulnerabilities_finding, 5, :with_secret_detection, pipeline: pipeline)
        end

        it 'processes all findings in batches' do
          expect { worker.perform(pipeline.id) }.to change {
            Vulnerabilities::FindingTokenStatus.count
          }.by(6)
        end

        it 'processes findings in batches' do
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 1)
          allow(worker).to receive(:process_findings_batch).and_call_original
          worker.perform(pipeline.id)
          expect(worker).to have_received(:process_findings_batch).exactly(6).times
        end

        it 'does not perform N+1 queries' do
          # Set a batch size that ensures all findings are processed in a single batch
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 20)
          create_list(:vulnerabilities_finding, 10, :with_secret_detection, pipeline: pipeline)

          # Count queries when processing all findings
          query_count = ActiveRecord::QueryRecorder.new do
            worker.perform(pipeline.id)
          end.count

          # We expect exactly 8 queries:
          # 1. Query to fetch the pipeline
          # 2. Query to fetch the project
          # 3. Batch start boundary query (find first record)
          # 4. Batch end boundary query (check for more records)
          # 5. Query to check if findings batch is empty
          # 6. Query to fetch all findings in the batch
          # 7. Query to fetch tokens
          # 8. Query to insert/update statuses
          expect(query_count).to be 8
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::Checks::SecretPushProtection::PayloadProcessor, feature_category: :secret_detection do
  include_context 'secrets check context'
  using RSpec::Parameterized::TableSyntax

  subject(:payload_processor) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  describe '#standardize_payloads' do
    context 'with a valid diff blob' do
      it 'returns a single GRPC payload built from the diff blob' do
        expect(project.repository).to receive(:diff_blobs_with_raw_info) do |raw_info, _options|
          expect(raw_info).to be_an(Array)
          expect(raw_info.size).to eq(1)

          changed_path = raw_info.first
          expect(changed_path).to be_a(Gitaly::ChangedPaths)
          expect(changed_path.path).to eq(".env")
          expect(changed_path.status).to eq(:ADDED)
          expect(changed_path.old_mode).to eq(0)
          expect(changed_path.new_mode).to eq(33188)
          expect(changed_path.old_blob_id).to eq("0000000000000000000000000000000000000000")
          expect(changed_path.new_blob_id).to eq("da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda")
          expect(changed_path.old_path).to eq("")
          expect(changed_path.score).to eq(0)
        end.and_call_original

        expected_diff_filters = [
          :DIFF_STATUS_ADDED,
          :DIFF_STATUS_MODIFIED,
          :DIFF_STATUS_TYPE_CHANGE,
          :DIFF_STATUS_COPIED,
          :DIFF_STATUS_RENAMED
        ]
        expect(project.repository).to receive(:find_changed_paths).with(
          anything,
          hash_including(diff_filters: expected_diff_filters)
        ).and_call_original

        payloads = payload_processor.standardize_payloads
        expect(payloads).to be_an(Array)
        expect(payloads.size).to eq(1)

        payload = payloads.first
        expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
        expect(payload.id).to eq(new_blob_reference)
        expect(payload.data).to include("BASE_URL=https://foo.bar")
        expect(payload.offset).to eq(1)
      end
    end

    context 'when secret_detection_transition_to_raw_info_gitaly_endpoint is disabled' do
      before do
        stub_feature_flags(secret_detection_transition_to_raw_info_gitaly_endpoint: false)
      end

      context 'with a valid diff blob' do
        it 'returns a single GRPC payload built from the diff blob' do
          expect(project.repository).to receive(:diff_blobs) do |blob_pairs, _options|
            expect(blob_pairs).to be_an(Array)
            expect(blob_pairs.size).to eq(1)

            blob_pair = blob_pairs.first
            expect(blob_pair).to be_a(Gitaly::DiffBlobsRequest::BlobPair)
            expect(blob_pair.left_blob).to eq("0000000000000000000000000000000000000000")
            expect(blob_pair.right_blob).to eq("da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda")
          end.and_call_original

          payloads = payload_processor.standardize_payloads
          expect(payloads).to be_an(Array)
          expect(payloads.size).to eq(1)

          payload = payloads.first
          expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
          expect(payload.id).to eq(new_blob_reference)
          expect(payload.data).to include("BASE_URL=https://foo.bar")
          expect(payload.offset).to eq(1)
        end
      end
    end

    context 'when secret_detection_filter_deleted_files is disabled' do
      before do
        stub_feature_flags(secret_detection_filter_deleted_files: false)
      end

      context 'with a valid diff blob' do
        it 'does not pass diff filters to find_changed_paths' do
          expect(project.repository).to receive(:find_changed_paths).with(
            anything,
            hash_including(diff_filters: nil)
          ).and_call_original

          payload_processor.standardize_payloads
        end
      end
    end

    context 'when parse_diffs returns an empty array due to invalid hunk header' do
      let(:bad_diff_blob) do
        ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ malformed header @@\n+some content\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      end

      before do
        allow(payload_processor).to receive(:get_diffs).and_return([bad_diff_blob])
      end

      it 'logs an error and returns nil when no payloads remain' do
        expect(secret_detection_logger).to receive(:error).with(
          hash_including("message" => a_string_including("Could not process hunk header"))
        )

        expect(payload_processor.standardize_payloads).to be_nil
      end
    end

    context 'when get_diffs returns nil or empty' do
      it 'returns nil' do
        allow(payload_processor).to receive(:get_diffs).and_return([])
        expect(payload_processor.standardize_payloads).to be_nil
      end
    end
  end

  describe '#parse_diffs' do
    let(:diff_blob) do
      ::Gitlab::GitalyClient::DiffBlob.new(
        left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: patch,
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    context 'with a valid diff patch containing two hunks' do
      let(:patch) do
        <<~DIFF
          @@ -0,0 +1,2 @@
          +one
          +two
          @@ -10,0 +11,1 @@
          +three
        DIFF
      end

      it 'returns two chunks with correct id, offset, and data' do
        parsed = payload_processor.parse_diffs(diff_blob)
        expect(parsed.pluck(:offset)).to match_array([1, 11])
        expect(parsed.pluck(:data)).to eq(%W[one\ntwo three])
        expect(parsed).to all(include(id: new_blob_reference))
      end
    end

    context 'with an invalid hunk header' do
      let(:patch) { "@@ bad header @@\n+foo\n" }

      it 'logs and returns []' do
        expect(secret_detection_logger).to receive(:error).with(
          hash_including("message" => a_string_including("Could not process hunk header"))
        )

        parsed = payload_processor.parse_diffs(diff_blob)
        expect(parsed).to eq([])
      end
    end

    context 'with special characters' do
      where(:line, :expected_data) do
        [
          ['+SECRET=glpat-123!@#$%^&*()', 'SECRET=glpat-123!@#$%^&*()'], # gitleaks:allow
          ['+TOKEN=glpat-💥💥💥', 'TOKEN=glpat-💥💥💥']
        ]
      end

      with_them do
        let(:patch) { "@@ -1,0 +1,1 @@\n#{line}\n" }

        it 'preserves emojis and special chars' do
          parsed = payload_processor.parse_diffs(diff_blob)
          expect(parsed.size).to eq(1)
          expect(parsed.first[:data]).to eq(expected_data)
        end
      end
    end
  end

  describe '#build_payload' do
    let(:datum) { { id: 'test-blob-id', data: 'test payload data', offset: 2 } }

    context 'with valid UTF-8 data' do
      it 'returns a GRPC::ScanRequest::Payload with matching attributes' do
        payload = payload_processor.build_payload(datum)
        expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
        expect(payload.id).to eq('test-blob-id')
        expect(payload.data).to eq('test payload data')
      end
    end

    context 'when data has invalid encoding' do
      let(:datum_id) { 'test-blob-id' }
      let(:datum_offset) { 2 }
      let(:original_encoding) { 'ASCII-8BIT' }

      let(:data_content) { +'encoded string' }

      let(:invalid_datum) do
        {
          id: datum_id,
          data: data_content,
          offset: datum_offset
        }
      end

      it 'returns nil and logs a warning' do
        expect(data_content).to receive(:encoding).and_return(original_encoding)
        expect(data_content).to receive(:dup).and_return(data_content)
        expect(data_content).to receive(:force_encoding).and_return(data_content)
        expect(data_content).to receive(:valid_encoding?).and_return(false)

        expect(secret_detection_logger).to receive(:warn).with(
          hash_including(
            "message" => format(
              Gitlab::Checks::SecretPushProtection::PayloadProcessor::LOG_MESSAGES[:invalid_encoding],
              { encoding: original_encoding }
            )
          )
        )

        result = payload_processor.build_payload(invalid_datum)
        expect(result).to be_nil
      end
    end

    context 'when passed an already-built payload' do
      let(:existing) do
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          id: 'test-blob-id',
          data: 'test payload data',
          offset: 3
        )
      end

      it 'returns it unmodified' do
        expect(payload_processor.build_payload(existing)).to be(existing)
      end
    end
  end
end

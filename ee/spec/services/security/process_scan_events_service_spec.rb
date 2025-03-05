# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanEventsService, feature_category: :vulnerability_management do
  let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :dast_observability) }

  let(:pipeline) { artifact.job.pipeline }
  let(:internal_event_name) { 'dummy_event_for_testing_abcdefg' }
  let(:internal_event_definition) do
    Gitlab::Tracking::EventDefinition.new(
      "config/events/#{internal_event_name}",
      {
        action: internal_event_name,
        internal_events: true,
        identifiers: %w[project user],
        additional_properties: {
          label: { description: 'desc' },
          property: { description: 'desc' },
          value: { description: 'desc' },
          content_type: { description: 'desc' },
          operations: { description: 'desc' },
          overrides_command: { description: 'desc' },
          per_request_script: { description: 'desc' },
          status: { description: 'desc' },
          version: { description: 'desc' },
          version_major: { description: 'desc' }
        }
      }
    )
  end

  before do
    artifact.job.update!(status: :success)
    allow(Gitlab::Tracking::EventDefinition).to receive_messages(
      find: internal_event_definition, internal_event_exists?: true)
  end

  describe '#execute' do
    shared_examples 'process security report' do
      context 'with security report' do
        let!(:service_object) { described_class.new(pipeline) }

        context 'with known event' do
          before do
            allow(service_object).to receive(:event_allowed?).with(internal_event_name).and_return(true)
          end

          it "calls track_internal_event with 'testing_unknown_events_abcdefg'" do
            expect { service_object.execute }.to trigger_internal_events(internal_event_name).with(
              project: pipeline.project,
              additional_properties: {
                content_type: "json",
                label: "openapi",
                operations: 10,
                overrides_command: 1,
                per_request_script: 1,
                property: "294f623d-b2ce-4568-8008-6fd4a5fb3330",
                status: "completed",
                value: 60,
                version: "5.5.5",
                version_major: 5
              }
            )
          end
        end

        context 'with unknown event' do
          it 'tracks and raises error in dev/test ::Security::ProcessScanEventsService::ScanEventNotInAllowListError' do
            expect { service_object.execute }.to raise_error(
              ::Security::ProcessScanEventsService::ScanEventNotInAllowListError,
              "Event not in allow list 'dummy_event_for_testing_abcdefg'")
          end

          it 'tracks error in prod ::Security::ProcessScanEventsService::ScanEventNotInAllowListError' do
            allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
            expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
              instance_of(::Security::ProcessScanEventsService::ScanEventNotInAllowListError), any_args)

            service_object.execute
          end
        end
      end
    end

    context 'with successful job' do
      include_examples 'process security report'
    end

    context 'with failed job' do
      before do
        artifact.job.update!(status: :failed)
      end

      include_examples 'process security report'
    end

    context 'with invalid security report JSON' do
      let(:artifact_invalid_json) { create(:ee_ci_job_artifact, :dast_observability) }
      let(:service_object) { described_class.new(artifact_invalid_json.job.pipeline) }

      before do
        # rubocop:disable AnyInstanceOf -- Each call to ProcessScanEventsService::report_artifacts results in different object instances being returned
        allow_any_instance_of(::Ci::JobArtifact).to receive(:each_blob)
          .and_yield("[][]{{(*$)@&%(*@&%^@$!_@)iowuejrfiqwoiqwfqwdfoij")
        # rubocop:enable AnyInstanceOf -- AST: Dynamic Analysis
      end

      it 'tracks error parsing job artifact' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(::JSON::ParserError),
          {
            pipeline: an_instance_of(::Ci::Pipeline),
            artifact: an_instance_of(::Ci::JobArtifact)
          }
        )

        expect { service_object.execute }.not_to trigger_internal_events(internal_event_name)
      end
    end
  end
end

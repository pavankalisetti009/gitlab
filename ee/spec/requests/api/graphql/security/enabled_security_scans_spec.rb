# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying enabled scans for a pipeline', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:variables) { { fullPath: project.full_path, pipelineIid: pipeline.iid } }
  let(:enabled_scans) { graphql_data.dig('project', 'pipeline', 'enabledSecurityScans') }
  let(:enabled_partial_scans) { graphql_data.dig('project', 'pipeline', 'enabledPartialSecurityScans') }

  let(:query) do
    <<~QUERY
    query enabledScans($fullPath: ID!, $pipelineIid: ID!) {
      project(fullPath: $fullPath) {
        pipeline(iid: $pipelineIid) {
          enabledSecurityScans {
            apiFuzzing
            clusterImageScanning
            containerScanning
            coverageFuzzing
            dast
            dependencyScanning
            sast
            secretDetection
          }
          enabledPartialSecurityScans {
            apiFuzzing
            clusterImageScanning
            containerScanning
            coverageFuzzing
            dast
            dependencyScanning
            sast
            secretDetection
          }
        }
      }
    }
    QUERY
  end

  def send_request
    post_graphql(query, variables: variables, current_user: user)
  end

  context 'when user does not have permission to read pipeline' do
    it 'does not return pipeline data' do
      send_request

      expect(graphql_data.dig('project', 'pipeline')).to be_nil
    end
  end

  context 'when user has permission to read pipeline' do
    before_all do
      project.add_developer(user)
    end

    it 'returns false for all fields when there are no scans' do
      send_request

      expect(enabled_scans).to eq({
        'apiFuzzing' => false,
        'clusterImageScanning' => false,
        'containerScanning' => false,
        'coverageFuzzing' => false,
        'dast' => false,
        'dependencyScanning' => false,
        'sast' => false,
        'secretDetection' => false
      })
      expect(enabled_partial_scans).to eq({
        'apiFuzzing' => false,
        'clusterImageScanning' => false,
        'containerScanning' => false,
        'coverageFuzzing' => false,
        'dast' => false,
        'dependencyScanning' => false,
        'sast' => false,
        'secretDetection' => false
      })
    end

    context 'when there are scans in the pipeline' do
      let_it_be(:sast_scan) { create(:security_scan, pipeline: pipeline, scan_type: :sast) }
      let_it_be(:dast_scan) { create(:security_scan, pipeline: pipeline, scan_type: :dast) }
      let_it_be(:sast_partial_scan) do
        create(:vulnerabilities_partial_scan, scan: sast_scan, pipeline: pipeline, scan_type: :sast)
      end

      it 'returns true for report types which have scans' do
        send_request

        expect(enabled_scans).to eq({
          'apiFuzzing' => false,
          'clusterImageScanning' => false,
          'containerScanning' => false,
          'coverageFuzzing' => false,
          'dast' => true,
          'dependencyScanning' => false,
          'sast' => true,
          'secretDetection' => false
        })
        expect(enabled_partial_scans).to eq({
          'apiFuzzing' => false,
          'clusterImageScanning' => false,
          'containerScanning' => false,
          'coverageFuzzing' => false,
          'dast' => false,
          'dependencyScanning' => false,
          'sast' => true,
          'secretDetection' => false
        })
      end
    end

    context 'when the scans are in a child pipeline' do
      let_it_be(:child_pipeline) { create(:ci_pipeline, child_of: pipeline) }
      let_it_be(:sast_scan) { create(:security_scan, pipeline: child_pipeline, scan_type: :sast) }
      let_it_be(:dast_scan) { create(:security_scan, pipeline: child_pipeline, scan_type: :dast) }
      let_it_be(:sast_partial_scan) do
        create(:vulnerabilities_partial_scan, scan: sast_scan, pipeline: child_pipeline, scan_type: :sast)
      end

      it 'returns true for report types which have scans' do
        send_request

        expect(enabled_scans).to eq({
          'apiFuzzing' => false,
          'clusterImageScanning' => false,
          'containerScanning' => false,
          'coverageFuzzing' => false,
          'dast' => true,
          'dependencyScanning' => false,
          'sast' => true,
          'secretDetection' => false
        })
        expect(enabled_partial_scans).to eq({
          'apiFuzzing' => false,
          'clusterImageScanning' => false,
          'containerScanning' => false,
          'coverageFuzzing' => false,
          'dast' => false,
          'dependencyScanning' => false,
          'sast' => true,
          'secretDetection' => false
        })
      end
    end
  end
end

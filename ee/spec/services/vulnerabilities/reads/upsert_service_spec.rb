# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Reads::UpsertService, feature_category: :vulnerability_management do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }

  let(:vulnerability) do
    create(:vulnerability,
      project: project,
      author: user,
      severity: :high,
      state: :detected,
      resolved_on_default_branch: false,
      present_on_default_branch: true)
  end

  let!(:finding) do
    create(:vulnerabilities_finding,
      project: project,
      scanner: scanner,
      vulnerability: vulnerability,
      location: { 'image' => 'alpine:3.4' })
  end

  describe '#execute' do
    before do
      Vulnerabilities::Read.where(vulnerability: vulnerability).delete_all
    end

    let(:execute_service) { described_class.new(vulnerabilities, attributes, projects: project).execute }

    context 'with single vulnerability' do
      let(:vulnerabilities) { vulnerability }
      let(:attributes) { {} }

      context 'when vulnerability is present on default branch' do
        context 'when no vulnerability_read exists' do
          it 'creates a vulnerability_read record' do
            expect { execute_service }.to change { Vulnerabilities::Read.count }.by(1)
          end

          it 'sets correct attributes from vulnerability' do
            execute_service
            created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

            expect(created_read).to have_attributes(
              vulnerability_id: vulnerability.id,
              project_id: vulnerability.project_id,
              scanner_id: finding.scanner_id,
              report_type: vulnerability.report_type,
              severity: vulnerability.severity,
              state: vulnerability.state,
              resolved_on_default_branch: vulnerability.resolved_on_default_branch,
              uuid: finding.uuid_v5,
              location_image: 'alpine:3.4',
              identifier_names: finding.identifiers.pluck(:name),
              has_remediations: vulnerability.has_remediations?
            )
          end

          it 'handles cluster_agent_id from vulnerability location' do
            finding.update!(location: { 'kubernetes_resource' => { 'agent_id' => '123' } })

            execute_service
            created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

            expect(created_read.cluster_agent_id).to eq('123')
          end
        end

        context 'when vulnerability_read already exists' do
          let!(:existing_read) do
            create(:vulnerability_read,
              vulnerability: vulnerability,
              project: project,
              scanner: scanner,
              severity: :low,
              state: :dismissed,
              uuid: finding.uuid_v5,
              report_type: vulnerability.report_type,
              resolved_on_default_branch: false)
          end

          it 'updates the existing record without creating a new one' do
            expect { execute_service }.not_to change { Vulnerabilities::Read.count }
          end

          it 'updates only changed attributes' do
            described_class.new(vulnerability, { severity: :critical }, projects: project).execute

            expect(existing_read.reload.severity).to eq('critical')
          end
        end
      end

      context 'when vulnerability is not present on default branch' do
        before do
          vulnerability.update!(present_on_default_branch: false)
        end

        it 'does not create or update any records' do
          expect { execute_service }.not_to change { Vulnerabilities::Read.count }
        end
      end

      context 'when vulnerability has no finding' do
        before do
          vulnerability.finding.destroy!
          vulnerability.reload
        end

        it 'does not create or update any records' do
          expect { execute_service }.not_to change { Vulnerabilities::Read.count }
        end
      end
    end

    context 'with multiple vulnerabilities' do
      let(:vulnerabilities) { [vulnerability, vulnerability2] }
      let(:attributes) { {} }
      let(:created_reads) { Vulnerabilities::Read.where(vulnerability: vulnerabilities) }

      let(:vulnerability2) do
        create(:vulnerability,
          project: project,
          author: user,
          severity: :medium,
          state: :confirmed,
          present_on_default_branch: true)
      end

      let!(:finding2) do
        create(:vulnerabilities_finding,
          project: project,
          scanner: scanner,
          vulnerability: vulnerability2)
      end

      before do
        Vulnerabilities::Read.where(vulnerability_id: [vulnerability.id, vulnerability2.id]).delete_all
      end

      it 'processes all valid vulnerabilities' do
        expect { execute_service }.to change { Vulnerabilities::Read.count }.by(2)
      end

      it 'creates vulnerability reads for all valid vulnerabilities' do
        execute_service

        expect(created_reads.pluck(:vulnerability_id)).to contain_exactly(vulnerability.id, vulnerability2.id)
      end

      it 'skips invalid vulnerabilities' do
        vulnerability2.update!(present_on_default_branch: false)

        execute_service

        created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)
        expect(created_read.vulnerability_id).to eq(vulnerability.id)
        expect(Vulnerabilities::Read.find_by(vulnerability: vulnerability2)).to be_nil
      end
    end

    context 'with custom attributes' do
      let(:vulnerabilities) { vulnerability }
      let(:attributes) { { dismissal_reason: 'used_in_tests', has_issues: true } }

      context 'when creating new record' do
        it 'applies custom attributes during creation' do
          execute_service
          created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

          expect(created_read).to have_attributes(
            dismissal_reason: 'used_in_tests',
            has_issues: true
          )
        end
      end

      context 'when updating existing record' do
        let!(:existing_read) do
          create(:vulnerability_read,
            vulnerability: vulnerability,
            project: project,
            scanner: scanner,
            severity: :low,
            state: :dismissed,
            uuid: finding.uuid_v5,
            report_type: vulnerability.report_type,
            resolved_on_default_branch: false)
        end

        it 'updates with custom attributes' do
          expect(existing_read.reload).to have_attributes(
            dismissal_reason: nil,
            has_issues: false
          )

          execute_service

          expect(existing_read.reload).to have_attributes(
            dismissal_reason: 'used_in_tests',
            has_issues: true
          )
        end
      end
    end

    context 'with attribute update conditions' do
      let(:vulnerabilities) { vulnerability }
      let(:attributes) { { severity: :critical, state: :resolved, resolved_on_default_branch: true } }

      let!(:existing_read) do
        create(:vulnerability_read,
          vulnerability: vulnerability,
          project: project,
          scanner: scanner,
          severity: :low,
          state: :dismissed,
          uuid: finding.uuid_v5,
          report_type: vulnerability.report_type,
          resolved_on_default_branch: false)
      end

      it 'updates multiple attributes' do
        execute_service

        expect(existing_read.reload).to have_attributes(
          severity: 'critical',
          state: 'resolved',
          resolved_on_default_branch: true
        )
      end

      context 'with explicit nil attributes' do
        let(:attributes) { { dismissal_reason: nil } }

        it 'updates explicit nil attributes' do
          existing_read.update!(dismissal_reason: 'used_in_tests')

          execute_service

          expect(existing_read.reload.dismissal_reason).to be_nil
        end
      end

      context 'with other supported attributes' do
        let(:attributes) do
          {
            has_issues: true,
            has_merge_request: true,
            traversal_ids: [1, 2, 3],
            has_remediations: true,
            archived: true,
            auto_resolved: true,
            identifier_names: ['CVE-2023-1234']
          }
        end

        it 'updates other supported attributes' do
          expect(existing_read.reload).to have_attributes(
            has_issues: false,
            has_merge_request: false,
            traversal_ids: project.namespace.traversal_ids,
            has_remediations: false,
            archived: false,
            auto_resolved: false,
            identifier_names: []
          )

          execute_service

          expect(existing_read.reload).to have_attributes(
            has_issues: true,
            has_merge_request: true,
            traversal_ids: [1, 2, 3],
            has_remediations: true,
            archived: true,
            auto_resolved: true,
            identifier_names: ['CVE-2023-1234']
          )
        end
      end
    end

    context 'with bulk operations' do
      let(:vulnerabilities) do
        create_list(:vulnerability, 3, project: project, author: user, present_on_default_branch: true)
      end

      let(:attributes) { { dismissal_reason: 'used_in_tests', has_issues: true } }

      before do
        vulnerabilities.each { |v| create(:vulnerabilities_finding, vulnerability: v, scanner: scanner) }
        Vulnerabilities::Read.where(vulnerability: vulnerabilities).delete_all
      end

      it 'applies attributes to all vulnerabilities' do
        execute_service

        Vulnerabilities::Read.where(vulnerability: vulnerabilities).find_each do |read|
          expect(read).to have_attributes(
            dismissal_reason: 'used_in_tests',
            has_issues: true
          )
        end
      end

      it 'processes all vulnerabilities efficiently' do
        expect { execute_service }.to change { Vulnerabilities::Read.count }.by(3)
      end
    end

    context 'with edge cases' do
      context 'when given empty vulnerability array' do
        let(:vulnerabilities) { [] }
        let(:attributes) { {} }

        it 'does nothing without error' do
          expect { described_class.new(vulnerabilities, attributes).execute }.not_to raise_error
        end
      end

      context 'when given nil vulnerability' do
        let(:vulnerabilities) { nil }
        let(:attributes) { {} }

        it 'does nothing without error' do
          expect { described_class.new(vulnerabilities, attributes).execute }.not_to raise_error
        end
      end

      context 'when finding has no location' do
        let(:vulnerabilities) { vulnerability }
        let(:attributes) { {} }

        it 'handles finding without location' do
          finding.update!(location: nil)

          execute_service
          created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

          expect(created_read.location_image).to be_nil
        end
      end

      context 'when finding has location but no image' do
        let(:vulnerabilities) { vulnerability }
        let(:attributes) { {} }

        it 'handles finding with location but no image' do
          finding.update!(location: { 'file' => 'test.rb' })

          execute_service
          created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

          expect(created_read.location_image).to be_nil
        end
      end

      context 'when vulnerability has no identifiers' do
        let(:vulnerabilities) { vulnerability }
        let(:attributes) { {} }

        it 'handles vulnerability without identifiers' do
          finding.identifiers.delete_all

          execute_service
          created_read = Vulnerabilities::Read.find_by(vulnerability: vulnerability)

          expect(created_read.identifier_names).to be_empty
        end
      end
    end

    context 'with feature flag disabled' do
      let(:vulnerabilities) { vulnerability }
      let(:attributes) { { severity: :critical } }

      before do
        stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
      end

      it 'does not perform any operations' do
        expect(Vulnerabilities::Read).not_to receive(:upsert_all)
        expect { execute_service }.not_to change { Vulnerabilities::Read.count }
      end
    end
  end
end

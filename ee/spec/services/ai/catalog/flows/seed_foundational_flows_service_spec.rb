# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::SeedFoundationalFlowsService, feature_category: :workflow_catalog do
  let_it_be(:user) { create(:user) }
  let_it_be(:default_organization) { create(:organization, id: Organizations::Organization::DEFAULT_ORGANIZATION_ID) }

  let(:service) { described_class.new(current_user: user, organization: default_organization) }

  describe '#execute' do
    context 'with valid conditions' do
      it 'seeds all foundational flows successfully' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Foundational flows seeded successfully')
        expect(Ai::Catalog::Item.foundational_flows.count).to be > 0
      end

      it 'creates items with required attributes' do
        service.execute

        Ai::Catalog::Item.foundational_flows.all do |item|
          expect(item).to have_attributes(
            organization_id: default_organization.id,
            item_type: 'flow',
            verification_level: 'gitlab_maintained',
            public: true,
            project_id: nil,
            foundational_flow_reference: be_present
          )
        end
      end

      it 'creates released versions for each item' do
        service.execute

        Ai::Catalog::Item.foundational_flows.each do |item|
          expect(item.latest_version).to be_present
          expect(item.latest_version.version).to eq('1.0.0')
          expect(item.latest_version).to be_released
          expect(item.latest_released_version).to eq(item.latest_version)
        end
      end

      it 'creates valid minimal flow definitions' do
        service.execute

        Ai::Catalog::Item.foundational_flows.each do |item|
          definition = item.latest_version.definition

          expect(definition['version']).to eq('v1')
          expect(definition['environment']).to eq('ambient')
          expect(definition['flow']['entry_point']).to eq('foundationalFlow')
          expect(definition['yaml_definition']).to be_present
        end
      end
    end

    context 'when items already exist' do
      it 'does not create duplicates when run multiple times' do
        service.execute
        initial_count = Ai::Catalog::Item.foundational_flows.count

        described_class.new(current_user: user, organization: default_organization).execute

        expect(Ai::Catalog::Item.foundational_flows.count).to eq(initial_count)
      end

      it 'updates existing items without creating new versions' do
        # Create an existing item
        existing_item = create(:ai_catalog_item,
          foundational_flow_reference: 'code_review/v1',
          name: 'Old Name',
          organization: default_organization
        )

        service.execute

        existing_item.reload
        expect(existing_item.name).to eq('Code Review')
        expect(existing_item.versions.count).to eq(1)
      end
    end

    context 'when error handling' do
      context 'when item validation fails' do
        before do
          allow_next_instance_of(Ai::Catalog::Item) do |item|
            allow(item).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
          end
        end

        it 'returns an error response with payload' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Failed to seed some foundational flows')
          expect(result.payload).to be_present
        end
      end
    end

    context 'with workflow filtering' do
      it 'only seeds workflows with foundational_flow_reference' do
        workflows_with_reference = Ai::Catalog::FoundationalFlow::ITEMS.count do |item|
          item[:foundational_flow_reference].present?
        end

        service.execute

        expect(Ai::Catalog::Item.foundational_flows.count).to eq(workflows_with_reference)
      end

      it 'seeds resolve_sast_vulnerability as a foundational workflow' do
        service.execute

        resolve_sast_item = Ai::Catalog::Item.find_by(
          foundational_flow_reference: 'resolve_sast_vulnerability/v1'
        )

        expect(resolve_sast_item).to be_present
        expect(resolve_sast_item.name).to eq('Resolve SAST Vulnerability')
      end
    end

    context 'with display_name usage' do
      it 'uses display_name from workflow definition instead of humanized name' do
        service.execute

        code_review_item = Ai::Catalog::Item.find_by(foundational_flow_reference: 'code_review/v1')

        expect(code_review_item.name).to eq('Code Review')
        expect(code_review_item.name).not_to eq('Code review/v1')
      end
    end

    context 'with workflow attributes mapping' do
      it 'correctly maps all workflow attributes for Code Review flow' do
        service.execute

        code_review_item = Ai::Catalog::Item.find_by(foundational_flow_reference: 'code_review/v1')

        expect(code_review_item).to have_attributes(
          name: 'Code Review',
          description: 'Streamline code reviews by analyzing code changes, comments, and linked issues.',
          foundational_flow_reference: 'code_review/v1',
          item_type: 'flow',
          verification_level: 'gitlab_maintained',
          public: true
        )
      end

      it 'correctly maps all workflow attributes for SAST FP Detection flow' do
        service.execute

        sast_item = Ai::Catalog::Item.find_by(foundational_flow_reference: 'sast_fp_detection/v1')

        expect(sast_item).to have_attributes(
          name: 'SAST False Positive Detection',
          description: 'Analyze critical SAST vulnerabilities.',
          foundational_flow_reference: 'sast_fp_detection/v1',
          item_type: 'flow',
          verification_level: 'gitlab_maintained',
          public: true
        )
      end

      it 'correctly maps all workflow attributes for Developer flow' do
        service.execute

        developer_item = Ai::Catalog::Item.find_by(foundational_flow_reference: 'developer/v1')

        expect(developer_item).to have_attributes(
          name: 'Developer',
          description: 'Convert issues into actionable merge requests.',
          foundational_flow_reference: 'developer/v1',
          item_type: 'flow',
          verification_level: 'gitlab_maintained',
          public: true
        )
      end

      it 'seeds exactly 7 foundational workflows' do
        service.execute

        # We have 7 foundational workflows
        expect(Ai::Catalog::Item.foundational_flows.count).to eq(7)
      end

      it 'ensures all seeded items have descriptions' do
        service.execute

        Ai::Catalog::Item.foundational_flows.each do |item|
          expect(item.description).to be_present
          expect(item.description).not_to include('/v1')
        end
      end
    end
  end
end

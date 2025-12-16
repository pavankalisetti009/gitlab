# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::RedactionService, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:private_group_with_access) { create(:group, :private) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:private_project) { create(:project, :private, group: private_group) }
  let_it_be(:private_project_with_access) { create(:project, :private, group: private_group_with_access) }

  before_all do
    private_group_with_access.add_developer(user)
  end

  before do
    stub_licensed_features(epics: true, security_dashboard: true)
  end

  describe '.supported_types' do
    it 'includes EE resource types' do
      expect(described_class.supported_types).to include('epics', 'vulnerabilities')
    end

    it 'includes CE resource types' do
      expect(described_class.supported_types).to include(
        'issues', 'merge_requests', 'projects', 'milestones', 'snippets'
      )
    end
  end

  describe '#execute' do
    subject(:result) { service.execute }

    let(:service) { described_class.new(user: user, resources_by_type: resources_by_type, source: 'test') }

    context 'with epics' do
      let_it_be(:public_epic) { create(:epic, group: group) }
      let_it_be(:private_epic) { create(:epic, group: private_group) }
      let_it_be(:accessible_epic) { create(:epic, group: private_group_with_access) }
      let_it_be(:confidential_epic) { create(:epic, :confidential, group: private_group_with_access) }

      context 'when user can access public epic' do
        let(:resources_by_type) { { 'epics' => [public_epic.id] } }

        it 'allows access' do
          expect(result).to eq({ 'epics' => { public_epic.id => true } })
        end
      end

      context 'when user cannot access private epic' do
        let(:resources_by_type) { { 'epics' => [private_epic.id] } }

        it 'denies access' do
          expect(result).to eq({ 'epics' => { private_epic.id => false } })
        end
      end

      context 'when user has group access' do
        let(:resources_by_type) { { 'epics' => [accessible_epic.id] } }

        it 'allows access' do
          expect(result).to eq({ 'epics' => { accessible_epic.id => true } })
        end
      end

      context 'when user has group access to confidential epic' do
        let(:resources_by_type) { { 'epics' => [confidential_epic.id] } }

        it 'allows access for group member' do
          expect(result).to eq({ 'epics' => { confidential_epic.id => true } })
        end
      end

      context 'when checking multiple epics at once' do
        let(:resources_by_type) do
          { 'epics' => [public_epic.id, private_epic.id, accessible_epic.id] }
        end

        it 'returns correct authorization for each epic' do
          expect(result).to eq({
            'epics' => {
              public_epic.id => true,
              private_epic.id => false,
              accessible_epic.id => true
            }
          })
        end
      end

      context 'with non-existent epic' do
        let(:resources_by_type) { { 'epics' => [non_existing_record_id] } }

        it 'denies access' do
          expect(result).to eq({ 'epics' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with vulnerabilities' do
      let_it_be(:accessible_vulnerability) { create(:vulnerability, project: private_project_with_access) }
      let_it_be(:inaccessible_vulnerability) { create(:vulnerability, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) { { 'vulnerabilities' => [accessible_vulnerability.id] } }

        it 'allows access' do
          expect(result).to eq({ 'vulnerabilities' => { accessible_vulnerability.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) { { 'vulnerabilities' => [inaccessible_vulnerability.id] } }

        it 'denies access' do
          expect(result).to eq({ 'vulnerabilities' => { inaccessible_vulnerability.id => false } })
        end
      end

      context 'when checking multiple vulnerabilities at once' do
        let(:resources_by_type) do
          { 'vulnerabilities' => [accessible_vulnerability.id, inaccessible_vulnerability.id] }
        end

        it 'returns correct authorization for each vulnerability' do
          expect(result).to eq({
            'vulnerabilities' => {
              accessible_vulnerability.id => true,
              inaccessible_vulnerability.id => false
            }
          })
        end
      end

      context 'with non-existent vulnerability' do
        let(:resources_by_type) { { 'vulnerabilities' => [non_existing_record_id] } }

        it 'denies access' do
          expect(result).to eq({ 'vulnerabilities' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with mixed CE and EE resource types' do
      let_it_be(:public_issue) { create(:issue, project: project) }
      let_it_be(:public_epic) { create(:epic, group: group) }
      let_it_be(:accessible_vulnerability) { create(:vulnerability, project: private_project_with_access) }
      let_it_be(:private_mr) { create(:merge_request, source_project: private_project) }

      let(:resources_by_type) do
        {
          'issues' => [public_issue.id],
          'epics' => [public_epic.id],
          'vulnerabilities' => [accessible_vulnerability.id],
          'merge_requests' => [private_mr.id]
        }
      end

      it 'handles both CE and EE resource types correctly' do
        expect(result).to eq({
          'issues' => { public_issue.id => true },
          'epics' => { public_epic.id => true },
          'vulnerabilities' => { accessible_vulnerability.id => true },
          'merge_requests' => { private_mr.id => false }
        })
      end
    end

    context 'with empty arrays for EE types' do
      let(:resources_by_type) { { 'epics' => [], 'vulnerabilities' => [] } }

      it 'returns empty hashes for those types' do
        expect(result).to eq({ 'epics' => {}, 'vulnerabilities' => {} })
      end
    end
  end

  describe 'load_resources_for_type behavior' do
    context 'when EE resource type has no preload associations defined' do
      let_it_be(:public_epic) { create(:epic, group: group) }
      let(:resources_by_type) { { 'epics' => [public_epic.id] } }
      let(:service) { described_class.new(user: user, resources_by_type: resources_by_type, source: 'test') }

      before do
        stub_const(
          "EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS",
          EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS.except('epics')
        )
      end

      it 'does not raise an error when preloads are not defined' do
        expect { service.execute }.not_to raise_error
      end

      it 'still performs authorization correctly' do
        result = service.execute
        expect(result).to eq({ 'epics' => { public_epic.id => true } })
      end
    end
  end
end

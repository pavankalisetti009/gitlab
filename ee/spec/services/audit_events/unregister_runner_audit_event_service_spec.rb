# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::UnregisterRunnerAuditEventService, feature_category: :runner do
  let_it_be(:user) { create(:user) }
  let_it_be(:owner) { create(:user) }

  let(:service) { described_class.new(runner, author, entity) }
  let(:common_attrs) do
    {
      author_id: -1,
      created_at: timestamp,
      target_type: runner.class.name,
      target_id: runner.id,
      ip_address: nil,
      details: {
        target_type: runner.class.name,
        target_id: runner.id,
        ip_address: nil
      }
    }
  end

  let(:attrs) do
    common_attrs.deep_merge(
      entity_id: entity.id,
      entity_type: entity.class.name,
      entity_path: entity.full_path,
      target_details: target_details,
      details: {
        custom_message: expected_custom_message,
        entity_path: entity.full_path,
        target_details: target_details
      }
    ).deep_merge(extra_attrs)
  end

  shared_examples 'expected audit event' do
    it 'returns audit event attributes' do
      travel_to(timestamp) do
        expect(track_event.attributes).to eq('id' => track_event.id, **attrs.stringify_keys)
      end
    end
  end

  shared_context 'when unregistering runner' do
    let(:runner_type) { runner.runner_type.chomp('_type') }
    let(:expected_custom_message) { "Unregistered #{runner_type} CI runner, never contacted" }
    let(:extra_attrs) { {} }

    context 'with authentication token author' do
      let(:author) { 'b6bce79c3a' }
      let(:extra_attrs) do
        {
          author_name: author[0...8],
          details: {
            author_name: author[0...8],
            runner_authentication_token: author[0...8]
          }
        }
      end

      it_behaves_like 'expected audit event'

      context 'with recent contact stored in Redis cache' do
        let(:last_contact) { Time.zone.local(2024, 10, 30) }
        let(:expected_custom_message) { "Unregistered #{runner_type} CI runner, last contacted #{last_contact}" }

        before do
          runner.cache_attributes(contacted_at: last_contact)
        end

        it_behaves_like 'expected audit event'
      end
    end

    context 'with User author' do
      let(:author) { user }
      let(:extra_attrs) do
        {
          author_id: author.id,
          author_name: author.name,
          details: { author_name: author.name }
        }
      end

      it_behaves_like 'expected audit event'
    end
  end

  describe '#track_event' do
    before do
      stub_licensed_features(admin_audit_log: true)
    end

    subject(:track_event) { service.track_event }

    let_it_be(:timestamp) { Time.zone.local(2021, 12, 28) }

    context 'for instance runner' do
      before do
        stub_licensed_features(extended_audit_events: true, admin_audit_log: true)
      end

      let(:runner) { create(:ci_runner, creator: owner) }

      include_context 'when unregistering runner' do
        let(:entity) { Gitlab::Audit::InstanceScope.new }
        let(:target_details) { ::Gitlab::Routing.url_helpers.admin_runner_path(runner) }
      end
    end

    context 'for group runner' do
      let_it_be(:entity) { create(:group) }
      let(:runner) { create(:ci_runner, :group, groups: [entity]) }

      include_context 'when unregistering runner' do
        let(:target_details) { ::Gitlab::Routing.url_helpers.group_runner_path(entity, runner) }
      end
    end

    context 'for project runner' do
      let_it_be(:entity) { create(:project) }
      let(:runner) { create(:ci_runner, :project, projects: [entity]) }

      include_context 'when unregistering runner' do
        let(:target_details) { ::Gitlab::Routing.url_helpers.project_runner_path(entity, runner) }
      end
    end
  end
end

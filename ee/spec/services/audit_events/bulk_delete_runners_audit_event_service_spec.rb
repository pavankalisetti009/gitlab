# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::BulkDeleteRunnersAuditEventService, feature_category: :fleet_visibility do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:service) { described_class.new(runners, user) }

  describe '#track_event' do
    before do
      stub_licensed_features(extended_audit_events: true, admin_audit_log: true)
    end

    subject(:track_event) { service.track_event }

    let_it_be(:runners) do
      [
        create(:ci_runner),
        create(:ci_runner, :group, groups: [group]),
        create(:ci_runner, :project, projects: [project])
      ]
    end

    let(:common_attrs) do
      {
        created_at: timestamp,
        ip_address: nil,
        target_details: nil,
        target_id: nil,
        target_type: nil,
        details: {
          ip_address: nil
        }
      }
    end

    let(:short_shas) { runners.map(&:short_sha).join(', ') }
    let(:timestamp) { Time.zone.local(2021, 12, 28) }
    let(:attrs) do
      common_attrs.deep_merge(
        author_id: user.id,
        author_name: user.name,
        entity_id: user.id,
        entity_type: user.class.name,
        entity_path: user.username,
        details: {
          author_name: user.name,
          custom_message: "Deleted CI runners in bulk. Runner tokens: [#{short_shas}]",
          entity_path: user.username,
          runner_ids: runners.map(&:id),
          runner_short_shas: runners.map(&:short_sha)
        }
      )
    end

    it 'returns audit event attributes' do
      travel_to(timestamp) do
        expect(track_event.attributes).to eq(
          **attrs.stringify_keys,
          "id" => track_event.id
        )
      end
    end
  end
end

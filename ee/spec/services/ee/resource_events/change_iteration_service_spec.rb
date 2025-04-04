# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceEvents::ChangeIterationService, feature_category: :team_planning do
  let_it_be(:timebox) { create(:iteration) }

  let(:created_at_time) { Time.utc(2019, 12, 30) }
  let(:add_timebox_args) { { old_iteration_id: nil } }
  let(:remove_timebox_args) { { old_iteration_id: timebox.id } }

  [:issue, :merge_request].each do |issuable|
    it_behaves_like 'timebox(milestone or iteration) resource events creator', ResourceIterationEvent do
      let_it_be(:resource) { create(issuable) } # rubocop:disable Rails/SaveBang
    end
  end

  describe 'events tracking' do
    let_it_be(:user) { create(:user) }

    subject(:changed_service_instance) { described_class.new(resource, user, old_iteration_id: nil) }

    context 'when the resource is a work item' do
      let(:resource) { create(:work_item, iteration: timebox) }

      it 'tracks work item usage data counters' do
        expect(Gitlab::UsageDataCounters::WorkItemActivityUniqueCounter)
          .to receive(:track_work_item_iteration_changed_action)
          .with(author: user)

        changed_service_instance.execute
      end
    end

    context 'when the resource is not a work item' do
      let(:resource) { create(:issue, iteration: timebox) }

      it 'does not track work item usage data counters' do
        expect(Gitlab::UsageDataCounters::WorkItemActivityUniqueCounter)
          .not_to receive(:track_work_item_iteration_changed_action)

        changed_service_instance.execute
      end
    end
  end

  describe '#create_event' do
    let_it_be(:user) { create(:user) }
    let(:resource) { create(:work_item, iteration: timebox) }
    let(:ancestor) { create(:work_item) }

    subject(:changed_service_instance) do
      described_class.new(resource, user, old_iteration_id: nil, automated: true, triggered_by_work_item: ancestor)
    end

    it 'updates the automated column' do
      changed_service_instance.execute

      expect(ResourceIterationEvent.last.automated).to be(true)
    end

    it 'updates the triggered_by_id column' do
      changed_service_instance.execute

      expect(ResourceIterationEvent.last.triggered_by_id).to be(ancestor.id)
    end
  end
end

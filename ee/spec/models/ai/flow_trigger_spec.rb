# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTrigger, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:service_account) }

  subject(:flow_trigger) { build(:ai_flow_trigger, project: project) }

  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:ai_catalog_item_consumer).class_name('Ai::Catalog::ItemConsumer').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:event_types) }
    it { is_expected.to validate_presence_of(:description) }

    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:config_path).is_at_most(255) }

    describe 'event_types_are_valid' do
      it 'rejects empty event_types array' do
        flow_trigger = build(:ai_flow_trigger, project: project, event_types: [])

        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:event_types]).to include("can't be blank")
      end

      it 'rejects nil event_types' do
        flow_trigger = build(:ai_flow_trigger, project: project, event_types: nil)

        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:event_types]).to include("can't be blank")
      end

      it 'allows valid event_types array' do
        flow_trigger = build(:ai_flow_trigger, project: project, event_types: [0])

        expect(flow_trigger).to be_valid
      end
    end

    describe 'user_is_service_account' do
      it 'rejects regular user' do
        regular_user = create(:user)
        flow_trigger = build(:ai_flow_trigger, project: project, user: regular_user)

        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:user]).to include('user must be a service account')
      end
    end

    describe 'exactly_one_config_source' do
      let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, project: project, item: create(:ai_catalog_flow)) }

      context 'when using config_path only' do
        it 'is valid' do
          flow_trigger = build(:ai_flow_trigger, project: project, config_path: 'path/to/config.yml')

          expect(flow_trigger).to be_valid
        end
      end

      context 'when using ai_catalog_item_consumer only' do
        it 'is valid' do
          flow_trigger =
            build(:ai_flow_trigger,
              project: project, config_path: nil, ai_catalog_item_consumer: item_consumer)

          expect(flow_trigger).to be_valid
        end
      end

      context 'when using both config_path and ai_catalog_item_consumer' do
        it 'is invalid' do
          flow_trigger = build(:ai_flow_trigger,
            project: project,
            config_path: 'path/to/config.yml',
            ai_catalog_item_consumer: item_consumer)

          expect(flow_trigger).not_to be_valid
          expect(flow_trigger.errors[:base]).to include('must have only one config_path or ai_catalog_item_consumer')
        end
      end

      context 'when using neither config_path nor ai_catalog_item_consumer' do
        it 'is invalid' do
          flow_trigger = build(:ai_flow_trigger, config_path: nil)

          expect(flow_trigger).not_to be_valid
          expect(flow_trigger.errors[:base]).to include('must have only one config_path or ai_catalog_item_consumer')
        end
      end
    end

    describe 'catalog_item_valid' do
      let(:item_consumer) { create(:ai_catalog_item_consumer, project: project, item: item) }

      let(:item) { create(:ai_catalog_flow) }

      context 'when item consumer project does not match the project' do
        let(:project) { create(:project) }

        it 'is invalid' do
          flow_trigger = build(:ai_flow_trigger, project: project, ai_catalog_item_consumer: item_consumer)

          expect(flow_trigger).not_to be_valid
          expect(flow_trigger.errors[:base]).to include('must have only one config_path or ai_catalog_item_consumer')
        end
      end

      context 'when item is not a flow' do
        let(:item) { create(:ai_catalog_agent) }

        it 'is invalid' do
          flow_trigger = build(:ai_flow_trigger, project: project, ai_catalog_item_consumer: item_consumer)

          expect(flow_trigger).not_to be_valid
          expect(flow_trigger.errors[:base]).to include('ai_catalog_item_consumer is not a flow')
        end
      end
    end
  end

  describe 'database constraints' do
    it 'has correct table name' do
      expect(described_class.table_name).to eq('ai_flow_triggers')
    end

    context 'when using loose foreign key on users.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_flow_trigger, project: project) }
        let!(:parent) { model.user }
      end
    end

    context 'when using loose foreign key on projects.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_flow_trigger, project: project) }
        let!(:parent) { model.project }
      end
    end
  end

  describe 'factory' do
    it 'creates a valid flow trigger' do
      flow_trigger = build(:ai_flow_trigger,
        project: project,
        user: user,
        description: 'Test flow trigger',
        event_types: [0])

      expect(flow_trigger).to be_valid
    end

    it 'can be created and persisted' do
      expect do
        create(:ai_flow_trigger,
          project: project,
          user: user,
          description: 'Test flow trigger',
          event_types: [0])
      end.to change { described_class.count }.by(1)
    end
  end

  describe 'event_types_are_valid validation' do
    it 'allows multiple valid event types' do
      valid_types = Ai::FlowTrigger::EVENT_TYPES.values
      flow_trigger = build(:ai_flow_trigger, project: project, event_types: valid_types)

      expect(flow_trigger).to be_valid
    end

    it 'rejects invalid event types' do
      flow_trigger = build(:ai_flow_trigger, project: project, event_types: [99])

      expect(flow_trigger).not_to be_valid
      expect(flow_trigger.errors[:event_types]).to include('contains invalid event types: 99')
    end

    it 'rejects mixed valid and invalid event types' do
      flow_trigger = build(:ai_flow_trigger, project: project, event_types: [0, 99, 100])

      expect(flow_trigger).not_to be_valid
      expect(flow_trigger.errors[:event_types]).to include('contains invalid event types: 99, 100')
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at on creation' do
      flow_trigger = create(:ai_flow_trigger,
        project: project,
        user: user,
        description: 'Test flow trigger')

      expect(flow_trigger.created_at).to be_present
      expect(flow_trigger.updated_at).to be_present
    end

    it 'updates updated_at on modification' do
      flow_trigger = create(:ai_flow_trigger,
        project: project,
        user: user,
        description: 'Test flow trigger')

      original_updated_at = flow_trigger.updated_at

      travel_to(1.minute.from_now) do
        flow_trigger.update!(description: 'Updated description')

        expect(flow_trigger.updated_at).to be > original_updated_at
      end
    end
  end

  describe 'scopes' do
    describe 'with_ids' do
      it 'filters triggers by id' do
        triggers = create_list(:ai_flow_trigger, 3, project: project)

        expect(project.ai_flow_triggers.with_ids([triggers[0].id, triggers[1].id])).to contain_exactly(
          triggers[0], triggers[1]
        )
      end
    end
  end

  describe '.triggered_on' do
    before do
      stub_const("#{described_class}::EVENT_TYPES", {
        mention: 0,
        comment: 1,
        issue_created: 2
      })
    end

    context 'when filtering by mention event type' do
      let!(:mention_trigger) do
        create(:ai_flow_trigger,
          project: project,
          user: user,
          event_types: [0],
          description: 'Mention trigger')
      end

      let!(:multiple_types_trigger) do
        create(:ai_flow_trigger,
          project: project,
          user: user,
          event_types: [0, 1],
          description: 'Multiple types trigger')
      end

      let!(:other_type_trigger) do
        create(:ai_flow_trigger,
          project: project,
          user: user,
          event_types: [1, 2],
          description: 'Other type trigger')
      end

      it 'returns triggers that contain the mention event type' do
        result = described_class.triggered_on(:mention)

        expect(result).to contain_exactly(mention_trigger, multiple_types_trigger)
      end

      it 'returns triggers that contain the comment event type' do
        result = described_class.triggered_on(:comment)

        expect(result).to contain_exactly(multiple_types_trigger, other_type_trigger)
      end
    end
  end
end

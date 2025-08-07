# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTrigger, feature_category: :duo_workflow do
  subject(:flow_trigger) { build(:ai_flow_trigger) }

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:event_types) }
    it { is_expected.to validate_presence_of(:description) }

    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:config_path).is_at_most(255) }

    describe 'config_path validation' do
      it 'allows nil config_path' do
        flow_trigger = build(:ai_flow_trigger, config_path: nil)
        expect(flow_trigger).to be_valid
      end

      it 'allows empty config_path' do
        flow_trigger = build(:ai_flow_trigger, config_path: '')
        expect(flow_trigger).to be_valid
      end

      it 'allows valid config_path' do
        flow_trigger = build(:ai_flow_trigger, config_path: '.gitlab/ai_flows/workflow.yml')
        expect(flow_trigger).to be_valid
      end

      it 'rejects config_path longer than 255 characters' do
        long_path = 'a' * 256
        flow_trigger = build(:ai_flow_trigger, config_path: long_path)
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:config_path]).to include('is too long (maximum is 255 characters)')
      end
    end

    describe 'description validation' do
      it 'rejects empty description' do
        flow_trigger = build(:ai_flow_trigger, description: '')
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:description]).to include("can't be blank")
      end

      it 'rejects nil description' do
        flow_trigger = build(:ai_flow_trigger, description: nil)
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:description]).to include("can't be blank")
      end

      it 'rejects description longer than 255 characters' do
        long_description = 'a' * 256
        flow_trigger = build(:ai_flow_trigger, description: long_description)
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:description]).to include('is too long (maximum is 255 characters)')
      end

      it 'allows valid description' do
        flow_trigger = build(:ai_flow_trigger, description: 'Valid description')
        expect(flow_trigger).to be_valid
      end
    end

    describe 'event_types validation' do
      it 'rejects empty event_types array' do
        flow_trigger = build(:ai_flow_trigger, event_types: [])
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:event_types]).to include("can't be blank")
      end

      it 'rejects nil event_types' do
        flow_trigger = build(:ai_flow_trigger, event_types: nil)
        expect(flow_trigger).not_to be_valid
        expect(flow_trigger.errors[:event_types]).to include("can't be blank")
      end

      it 'allows valid event_types array' do
        flow_trigger = build(:ai_flow_trigger, event_types: [0])
        expect(flow_trigger).to be_valid
      end
    end
  end

  describe 'database constraints' do
    it 'has correct table name' do
      expect(described_class.table_name).to eq('ai_flow_triggers')
    end

    context 'with loose foreign key on users.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_flow_trigger, user: create(:user), project: create(:project)) }
        let!(:parent) { model.user }
      end
    end

    context 'with loose foreign key on projects.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_flow_trigger, user: create(:user), project: create(:project)) }
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
      flow_trigger = build(:ai_flow_trigger, event_types: valid_types)
      expect(flow_trigger).to be_valid
    end

    it 'rejects invalid event types' do
      flow_trigger = build(:ai_flow_trigger, event_types: [99])
      expect(flow_trigger).not_to be_valid
      expect(flow_trigger.errors[:event_types]).to include('contains invalid event types: 99')
    end

    it 'rejects mixed valid and invalid event types' do
      flow_trigger = build(:ai_flow_trigger, event_types: [0, 99, 100])
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
end

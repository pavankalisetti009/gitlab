# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Checkpoint, feature_category: :duo_agent_platform do
  def ms_timestamp(time)
    time.change(nsec: (time.nsec / 1000) * 1000)
  end

  let_it_be(:ts_first) { '619a978e-9f3a-7174-9d92-b51f500b8a5b' }
  let_it_be(:ts_second) { '719a978e-9f3a-7174-9d92-b51f500b8a5b' }

  let_it_be(:checkpoint1) do
    create(:duo_workflows_checkpoint, thread_ts: ts_first, created_at: ms_timestamp(3.days.ago))
  end

  let_it_be(:checkpoint2) do
    create(:duo_workflows_checkpoint, thread_ts: ts_second, created_at: ms_timestamp(2.days.ago))
  end

  let_it_be(:write1) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  let_it_be(:write2) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  it { is_expected.to validate_presence_of(:thread_ts) }
  it { is_expected.to validate_presence_of(:checkpoint) }
  it { is_expected.to validate_presence_of(:metadata) }

  it_behaves_like 'sync workflow attributes' do
    subject { build(:duo_workflows_checkpoint) }
  end

  it "touches workflow on save" do
    workflow = create(:duo_workflows_workflow)
    expect(workflow.created_at).to eq(workflow.updated_at)

    create(:duo_workflows_checkpoint, workflow: workflow)
    expect(workflow.updated_at).to be > workflow.created_at
  end

  describe '.ordered_with_writes' do
    it 'returns checkpoints ordered by thread_ts with writes included' do
      result = described_class.ordered_with_writes

      expect(result.to_a).to eq([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe '.with_checkpoint_writes' do
    it 'returns checkpoint, including checkpoint_writes' do
      result = described_class.with_checkpoint_writes

      expect(result.to_a).to match_array([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe '.earliest' do
    let_it_be(:ts_earliest) { '019a978e-9f3a-7174-9d92-b51f500b8a5b' }
    let_it_be(:checkpoint3) do
      create(:duo_workflows_checkpoint, thread_ts: ts_earliest, created_at: ms_timestamp(2.hours.ago))
    end

    it 'returns the checkpoint with the earliest thread_ts' do
      expect(described_class.earliest).to eq(checkpoint3)
    end

    context 'when there are no checkpoints' do
      it 'returns nil' do
        described_class.delete_all
        expect(described_class.earliest).to be_nil
      end
    end
  end

  describe '.latest' do
    let_it_be(:ts_latest) { '919a978e-9f3a-7174-9d92-b51f500b8a5b' }
    let_it_be(:checkpoint3) do
      create(:duo_workflows_checkpoint, thread_ts: ts_latest, created_at: ms_timestamp(7.days.ago))
    end

    it 'returns the checkpoint with the latest thread_ts' do
      expect(described_class.latest).to eq(checkpoint3)
    end

    context 'when there are no checkpoints' do
      it 'returns nil' do
        described_class.delete_all
        expect(described_class.latest).to be_nil
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }

    describe '#checkpoint_writes' do
      let_it_be(:write3) { create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts) }
      let_it_be(:write4) { create(:duo_workflows_checkpoint_write, workflow: checkpoint2.workflow) }

      it 'returns writes for the same workflow having same thread_ts' do
        expect(checkpoint1.checkpoint_writes).to match_array([write1, write2])
      end

      it 'has many checkpoint_writes' do
        is_expected.to have_many(:checkpoint_writes)
          .conditions(Ai::DuoWorkflows::CheckpointWrite.arel_table[:workflow_id]
            .eq(described_class.arel_table[:workflow_id]))
          .with_foreign_key(:thread_ts)
          .with_primary_key(:thread_ts)
          .inverse_of(:checkpoint)
      end
    end
  end

  describe '.find' do
    it 'finds by single id using find_by_id' do
      expect(described_class).to receive(:find_by_id).with(checkpoint1.id.first)
      described_class.find(checkpoint1.id.first)
    end

    it 'falls back to super for array arguments' do
      expect(
        described_class.find([checkpoint1.id.first, checkpoint1.created_at])
      ).to eq(checkpoint1)
    end
  end

  describe '#to_global_id' do
    it 'returns a GlobalID with the first id element' do
      gid = checkpoint1.to_global_id
      expect(gid).to be_a(GlobalID)
      expect(gid.model_id).to eq(checkpoint1.id.first.to_s)
    end
  end
end

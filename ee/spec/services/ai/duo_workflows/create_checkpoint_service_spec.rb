# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateCheckpointService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:workflow) { create(:duo_workflows_workflow, **container_params) }
    let(:container_params) { { project: project } }
    let(:thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:parent_ts) { Gitlab::Utils.uuid_v7 }
    let(:metadata) { { another_key: 'another value' } }
    let(:params) { { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' }, metadata: metadata } }

    before do
      allow(GraphqlTriggers).to receive(:workflow_events_updated)
    end

    subject(:execute) do
      described_class
        .new(workflow: workflow, params: params)
        .execute
    end

    it 'creates a new checkpoint' do
      expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
      expect(execute[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
      expect(execute[:checkpoint].workflow).to eq(workflow)
      expect(execute[:checkpoint].project).to eq(project)
      expect(execute[:checkpoint].thread_ts).to eq(thread_ts)
      expect(execute[:checkpoint].parent_ts).to eq(parent_ts)
      expect(execute[:checkpoint].checkpoint).to eq({ 'key' => 'value' })
      expect(execute[:checkpoint].metadata).to eq({ 'another_key' => 'another value' })
      expect(GraphqlTriggers).to have_received(:workflow_events_updated).with(execute[:checkpoint])
    end

    context 'when namespace-level workflow' do
      let(:container_params) { { namespace: group } }

      it 'creates a new checkpoint' do
        expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
        expect(execute[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
        expect(execute[:checkpoint].workflow).to eq(workflow)
        expect(execute[:checkpoint].namespace).to eq(group)
      end
    end

    context 'when there is invalid params' do
      let(:thread_ts) { '' }

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message].to_s).to include("can't be blank")
        expect(GraphqlTriggers).not_to have_received(:workflow_events_updated).with(execute[:checkpoint])
      end
    end

    describe 'setting goal when first checkpoint' do
      let(:goal) { 'Hello, World!' }
      let(:checkpoint) do
        {
          "channel_values" => {
            "__start__" => {
              "goal" => goal
            }
          }
        }
      end

      let(:params) { { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata } }

      context 'when first checkpoint' do
        it 'updates the workflows goal to be new goal' do
          expect { execute }.to change { workflow.reload.goal }.to('Hello, World!')
        end

        context 'when goal is nil' do
          let(:goal) { nil }

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when goal is blank' do
          let(:goal) { '' }

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when goal field is not present' do
          let(:checkpoint) do
            {
              "channel_values" => {
                "__start__" => {
                  "another_goal" => goal
                }
              }
            }
          end

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end
      end

      context 'when not first checkpoint' do
        let!(:existing_checkpoint) do
          create(:duo_workflows_checkpoint, workflow: workflow)
        end

        it 'does not update the workflows goal' do
          expect { execute }.to not_change { workflow.reload.goal }
        end
      end
    end
  end
end

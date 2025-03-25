# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectNoteEntity, feature_category: :groups_and_projects do
  include Gitlab::Routing

  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create persisted objects for this test.
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:amazon_q_service_account) { create(:user) }

  let(:note) { create(:note, project: project) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  # rubocop:disable RSpec/VerifiedDoubles -- The exact type of the request object is unclear in this context.
  let(:request) { double('request', current_user: user, noteable: note.noteable) }
  # rubocop:enable RSpec/VerifiedDoubles

  let(:entity) { described_class.new(note, request: request) }

  subject(:entity_as_json) { entity.as_json }

  before do
    ::Ai::Setting.instance.update!(amazon_q_service_account_user: amazon_q_service_account)
    stub_licensed_features(amazon_q: true)
  end

  describe '#amazon_q_quick_actions_path' do
    context 'when Amazon Q is connected' do
      before do
        allow(Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      context 'when the Amazon Q service account exists' do
        context 'when the note author is the Amazon Q service account' do
          # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create persisted objects for this test.
          let(:note) { create(:note, project: project, author: amazon_q_service_account) }
          # rubocop:enable RSpec/FactoryBot/AvoidCreate

          it 'includes the amazon_q_quick_actions_path' do
            expect(entity_as_json).to include(:amazon_q_quick_actions_path)
          end

          it 'returns the correct path' do
            expect(entity_as_json[:amazon_q_quick_actions_path]).to eq(amazon_q_quick_actions_path)
          end
        end

        context 'when the note author is not the Amazon Q service account' do
          it 'includes the amazon_q_quick_actions_path as nil' do
            expect(entity_as_json[:amazon_q_quick_actions_path]).to be_nil
          end
        end
      end

      context 'when the Amazon Q service account is nil' do
        before do
          allow(Ai::Setting.instance).to receive(:amazon_q_service_account_user).and_return(nil)
        end

        it 'includes the amazon_q_quick_actions_path as nil' do
          expect(entity_as_json[:amazon_q_quick_actions_path]).to be_nil
        end
      end
    end

    context 'when Amazon Q is not connected' do
      before do
        allow(Ai::AmazonQ).to receive(:connected?).and_return(false)
      end

      it 'includes the amazon_q_quick_actions_path as nil' do
        expect(entity_as_json[:amazon_q_quick_actions_path]).to be_nil
      end
    end
  end
end

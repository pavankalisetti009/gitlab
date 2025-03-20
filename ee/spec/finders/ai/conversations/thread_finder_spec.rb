# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversations::ThreadFinder, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }

  let_it_be(:thread_1) { create(:ai_conversation_thread, user: user, last_updated_at: 1.day.ago) }
  let_it_be(:thread_2) { create(:ai_conversation_thread, user: user) }
  let_it_be(:thread_3) { create(:ai_conversation_thread, user: another_user) }

  let(:params) { {} }

  subject(:threads) { described_class.new(user, params).execute }

  it 'returns threads' do
    expect(threads).to eq([thread_2, thread_1])
  end

  context 'when filtering by id' do
    let(:params) { { id: thread_1.id } }

    it 'returns the thread' do
      expect(threads).to eq([thread_1])
    end
  end

  context 'when filtering by conversation_type' do
    let(:params) { { conversation_types: :duo_chat } }

    it 'returns threads' do
      expect(threads).to eq([thread_2, thread_1])
    end
  end

  describe 'fallback behavior on absence of duo_chat threads' do
    let(:finder) { described_class.new(user, params) }

    context 'when requesting duo chat threads' do
      let(:params) { { conversation_type: 'duo_chat' } }

      context 'when there are no existing duo_chat threads' do
        before do
          user.ai_conversation_threads.duo_chat.delete_all
        end

        context 'when there is a legacy thread' do
          let!(:legacy_thread) do
            create(:ai_conversation_thread, user: user, conversation_type: 'duo_chat_legacy')
          end

          it 'copies the last legacy thread as a new duo_chat thread' do
            expect do
              result = finder.execute

              expect(result.size).to eq(1)

              new_thread = result.first

              expect(new_thread.id).to be > legacy_thread.id
              expect(new_thread.conversation_type).to eq('duo_chat')
            end.to change { Ai::Conversation::Thread.count }.by(1)
          end
        end

        context 'when there is no legacy thread' do
          it 'returns an empty relation' do
            expect do
              expect(finder.execute).to be_empty
            end.not_to change { Ai::Conversation::Thread.count }
          end
        end
      end

      context 'when there are existing duo_chat threads' do
        it 'does not copy legacy thread' do
          expect do
            result = finder.execute
            expect(result.count).to eq(2)
          end.not_to change { Ai::Conversation::Thread.count }
        end
      end

      context 'when a inaccessible ID is provided' do
        let(:params) { { conversation_type: 'duo_chat', id: thread_3.id } }

        it 'does not create thread' do
          expect do
            expect(finder.execute).to be_empty
          end.not_to change { Ai::Conversation::Thread.count }
        end
      end
    end
  end
end

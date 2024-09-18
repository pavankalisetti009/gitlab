# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatStorage, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:another_user) { build_stubbed(:user) }
  let(:request_id) { 'uuid' }
  let(:timestamp) { Time.current.to_s }
  let(:payload) do
    {
      timestamp: timestamp,
      request_id: request_id,
      errors: ['some error1', 'another error'],
      role: 'user',
      content: 'response',
      user: user,
      referer_url: 'http://127.0.0.1:3000',
      additional_context: Gitlab::Llm::AiMessageAdditionalContext.new(
        [
          { category: 'file', id: 'additonial_context.rb', content: 'puts "additional context"' },
          { category: 'snippet', id: 'print_context_method', content: 'def additional_context; puts "context"; end' }
        ]
      )
    }
  end

  let(:agent_version_id) { 1 }

  subject { described_class.new(user, agent_version_id) }

  before do
    attributes = payload.except(:user).merge(content: 'other user unrelated cache', user: another_user)
    build(:ai_chat_message, attributes).save!
  end

  describe '#add' do
    let(:message) { build(:ai_chat_message, payload) }

    it 'adds new message', :aggregate_failures do
      uuid = 'unique_id'

      expect(SecureRandom).to receive(:uuid).once.and_return(uuid)
      expect(subject.messages).to be_empty

      subject.add(message)

      last = subject.messages.last
      expect(last.id).to eq(uuid)
      expect(last.user).to eq(user)
      expect(last.agent_version_id).to eq(agent_version_id)
      expect(last.request_id).to eq(request_id)
      expect(last.errors).to eq(['some error1', 'another error'])
      expect(last.content).to eq('response')
      expect(last.role).to eq('user')
      expect(last.ai_action).to eq('chat')
      expect(last.timestamp).not_to be_nil
      expect(last.referer_url).to eq('http://127.0.0.1:3000')
      expect(last.extras['additional_context']).to eq(payload[:additional_context].to_a)
    end

    context 'with MAX_MESSAGES limit' do
      before do
        stub_const('Gitlab::Llm::ChatStorage::MAX_MESSAGES', 2)
      end

      it 'removes oldest messages if we reach maximum message limit' do
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg2')))

        expect(subject.messages.map(&:content)).to eq(%w[msg1 msg2])

        subject.add(build(:ai_chat_message, payload.merge(content: 'msg3')))

        expect(subject.messages.map(&:content)).to eq(%w[msg2 msg3])
      end
    end
  end

  describe '#set_has_feedback' do
    let(:message) { create(:ai_chat_message, user: user, agent_version_id: agent_version_id) }

    it 'marks the message as having feedback' do
      subject.set_has_feedback(message)

      expect(subject.messages.find { |m| m.id == message.id }.extras['has_feedback']).to be(true)
    end
  end

  describe '#messages' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'assistant', request_id: '2')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant', request_id: '3')))
    end

    it 'returns all records for this user' do
      expect(subject.messages.map(&:content)).to eq(%w[msg1 msg2 msg3])
    end

    it 'a message contains additional context' do
      expect(subject.messages.last.extras['additional_context']).to eq(payload[:additional_context].to_a)
    end
  end

  describe '#messages_by' do
    let(:filters) { {} }

    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'assistant', request_id: '2')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant', request_id: '3')))
    end

    it 'returns all records for this user' do
      expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg1 msg2 msg3])
    end

    context 'when filtering by role' do
      let(:filters) { { roles: ['user'] } }

      it 'returns only records for this role' do
        expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg1])
      end
    end

    context 'when filtering by request_ids' do
      let(:filters) { { request_ids: %w[2 3] } }

      it 'returns only records with the same request_id' do
        expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg2 msg3])
      end
    end
  end

  describe '#last_conversation' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user', request_id: '3')))
    end

    it 'returns from current history' do
      expect(described_class).to receive(:last_conversation).and_call_original
      expect(subject.last_conversation.map(&:content)).to eq(%w[msg1 msg2])
    end
  end

  describe '.last_conversation' do
    let(:result) { described_class.last_conversation(messages).map(&:content) }

    context 'when there is no /reset message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user' do
        expect(result).to eq(%w[msg1 msg2])
      end
    end

    context 'when there is /reset message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg3', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg5', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg6', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user since last /reset message' do
        expect(result).to eq(%w[msg5 msg6])
      end
    end

    context 'when there is /reset message as the last message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user since last /reset message' do
        expect(result).to be_empty
      end
    end
  end

  describe '#clean!' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'user', request_id: '3')))
      subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
    end

    it 'returns clears all chat messages' do
      expect(subject.messages.size).to eq(4)

      subject.clean!

      expect(subject.messages).to be_empty
    end
  end

  describe '#messages_up_to' do
    let(:messages) do
      [
        build(:ai_chat_message, payload.merge(content: 'msg1', role: 'assistant')),
        build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user')),
        build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant'))
      ]
    end

    before do
      messages.each { |m| subject.add(m) }
    end

    it 'returns first n messages up to one with matching message id' do
      expect(subject.messages_up_to(messages[1].id)).to eq(messages.first(2))
    end

    it 'returns [] if message id is not found' do
      expect(subject.messages_up_to('missing id')).to eq([])
    end
  end
end

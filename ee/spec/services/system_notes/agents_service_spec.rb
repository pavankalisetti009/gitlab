# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::AgentsService, feature_category: :duo_agent_platform do
  let_it_be(:namespace) { create(:namespace, path: 'test-namespace') }
  let_it_be(:project) { create(:project, :repository, namespace: namespace, path: 'test-project') }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:agent_author) { create(:user) }

  let(:noteable) { issue }
  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }
  let(:session_id) { '123' }
  let(:expected_session_url) { "http://localhost/test-namespace/test-project/-/automate/agent-sessions/123" }

  before do
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:agent_author).and_return(agent_author)
    end
  end

  describe '#agent_session_started' do
    let(:trigger_source) { user }

    subject(:system_note) { service.agent_session_started(session_id, trigger_source) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_started' }
    end

    context 'when session is started by user' do
      it 'sets the note text with user trigger' do
        expected_trigger_url = "http://localhost/#{trigger_source.username}"
        expected_note = "started session [#{session_id}](#{expected_session_url}) " \
          "triggered by [#{trigger_source.name}](#{expected_trigger_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when trigger_source is nil' do
      let(:trigger_source) { nil }

      it 'sets the note text without trigger source' do
        expected_note = "started session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when trigger_source is empty string' do
      let(:trigger_source) { '' }

      it 'sets the note text without trigger source' do
        expected_note = "started session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_completed' do
    subject(:system_note) { service.agent_session_completed(session_id) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_completed' }
    end

    context 'when session is completed successfully' do
      it 'sets the note text' do
        expected_note = "completed session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_failed' do
    let(:reason) { nil }

    subject(:system_note) { service.agent_session_failed(session_id, reason) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_failed' }
    end

    context 'when session fails without reason' do
      it 'sets the note text without reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when session fails with reason' do
      let(:reason) { 'dropped' }

      it 'sets the note text with reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed (dropped)"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when reason is empty string' do
      let(:reason) { '' }

      it 'sets the note text without reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe 'tracks different noteables' do
    context 'when noteable is a merge request' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let(:noteable) { merge_request }

      it 'creates system note for merge request' do
        note = service.agent_session_started(session_id, user)
        expect(note.noteable).to eq(merge_request)
        expect(note.project).to eq(project)
        expect(note.author).to eq(agent_author)
      end
    end

    context 'when noteable is an Issue' do
      it 'creates system note for Issue' do
        note = service.agent_session_started(session_id, user)
        expect(note.noteable).to eq(issue)
        expect(note.project).to eq(project)
        expect(note.author).to eq(agent_author)
      end
    end
  end

  describe '#format_trigger_source' do
    subject(:formatted_trigger_source) { service.send(:format_trigger_source, trigger_source) }

    context 'when trigger_source is a User' do
      let(:trigger_source) { user }

      it 'returns a markdown link with user name and profile URL' do
        expected_url = "http://localhost/#{user.username}"
        expected_result = "[#{user.name}](#{expected_url})"

        expect(formatted_trigger_source).to eq(expected_result)
      end

      context 'when user name contains HTML characters' do
        let(:trigger_source) { create(:user, name: 'Jane & "Doe"') }

        it 'escapes HTML characters in the user name' do
          expect(formatted_trigger_source).to include('&amp;')
          expect(formatted_trigger_source).to include('&quot;')
          expect(formatted_trigger_source).not_to include('"Doe"')
        end
      end

      context 'when user name contains special markdown characters' do
        let(:trigger_source) { create(:user, name: 'Jane [Doe]') }

        it 'escapes the special characters' do
          expected_url = "http://localhost/#{trigger_source.username}"
          escaped_name = ERB::Util.html_escape(trigger_source.name)
          expected_result = "[#{escaped_name}](#{expected_url})"

          expect(formatted_trigger_source).to eq(expected_result)
        end
      end
    end

    context 'when trigger_source is a String' do
      let(:trigger_source) { 'Pipeline' }

      it 'returns the escaped string' do
        expect(formatted_trigger_source).to eq('Pipeline')
      end

      context 'when string contains HTML characters' do
        let(:trigger_source) { '<script>alert("xss")</script>' }

        it 'escapes HTML characters' do
          expect(formatted_trigger_source).to eq('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
          expect(formatted_trigger_source).not_to include('<script>')
        end
      end

      context 'when string contains special characters' do
        let(:trigger_source) { 'CI/CD Pipeline & Automation' }

        it 'escapes special characters' do
          escaped_result = ERB::Util.html_escape(trigger_source)
          expect(formatted_trigger_source).to eq(escaped_result)
          expect(formatted_trigger_source).to include('&amp;')
        end
      end
    end

    context 'when trigger_source is a Symbol' do
      let(:trigger_source) { :trigger_agent }

      it 'converts to string and escapes it' do
        expect(formatted_trigger_source).to eq('trigger_agent')
      end
    end

    context 'when trigger_source is an Integer' do
      let(:trigger_source) { 42 }

      it 'converts to string' do
        expect(formatted_trigger_source).to eq('42')
      end
    end

    context 'when trigger_source is nil' do
      let(:trigger_source) { nil }

      it 'returns empty string' do
        expect(formatted_trigger_source).to eq('')
      end
    end
  end
end

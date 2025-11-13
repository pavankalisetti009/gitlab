# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::AgentsService, feature_category: :duo_agent_platform do
  let_it_be(:namespace) { create(:namespace, path: 'test-namespace') }
  let_it_be(:project) { create(:project, :repository, namespace: namespace, path: 'test-project') }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:author) { create(:user) }

  let(:noteable) { issue }
  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }
  let(:session_id) { '123' }
  let(:expected_session_url) { "http://localhost/test-namespace/test-project/-/automate/agent-sessions/123" }

  describe '#agent_session_started' do
    let(:trigger_source) { 'User' }
    let(:agent_name) { 'Duo Developer' }

    subject(:system_note) { service.agent_session_started(session_id, trigger_source, agent_name) }

    it_behaves_like 'a system note' do
      let(:action) { 'duo_agent_started' }
    end

    context 'when session is started by user' do
      it 'sets the note text with default values' do
        expected_note = "**Duo Developer** started session [#{session_id}](#{expected_session_url}) triggered by User"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when session is started by pipeline' do
      let(:trigger_source) { 'Pipeline' }

      it 'sets the note text with pipeline trigger' do
        expected_note = "**Duo Developer** started session [#{session_id}](#{expected_session_url}) " \
          "triggered by Pipeline"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when using custom agent name' do
      let(:agent_name) { 'Custom Agent' }

      it 'sets the note text with custom agent name' do
        expected_note = "**Custom Agent** started session [#{session_id}](#{expected_session_url}) triggered by User"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when trigger_source is nil' do
      let(:trigger_source) { nil }

      it 'sets the note text without trigger source' do
        expected_note = "**Duo Developer** started session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_completed' do
    let(:session_id) { '123' }
    let(:agent_name) { 'Duo Developer' }

    subject(:system_note) { service.agent_session_completed(session_id, agent_name) }

    it_behaves_like 'a system note' do
      let(:action) { 'duo_agent_completed' }
    end

    context 'when session is completed successfully' do
      it 'sets the note text with default values' do
        expected_note = "**Duo Developer** completed session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when using custom agent name' do
      let(:agent_name) { 'Custom Agent' }

      it 'sets the note text with custom agent name' do
        expected_note = "**Custom Agent** completed session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_failed' do
    let(:session_id) { '123' }
    let(:reason) { nil }
    let(:agent_name) { 'Duo Developer' }

    subject(:system_note) { service.agent_session_failed(session_id, reason, agent_name) }

    it_behaves_like 'a system note' do
      let(:action) { 'duo_agent_failed' }
    end

    context 'when session fails without reason' do
      it 'sets the note text without reason' do
        expected_note = "**Duo Developer** session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when session fails with reason' do
      let(:reason) { 'dropped' }

      it 'sets the note text with reason' do
        expected_note = "**Duo Developer** session [#{session_id}](#{expected_session_url}) failed (dropped)"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when using custom agent name' do
      let(:agent_name) { 'Custom Agent' }

      it 'sets the note text with custom agent name' do
        expected_note = "**Custom Agent** session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when reason is empty string' do
      let(:reason) { '' }

      it 'sets the note text without reason' do
        expected_note = "**Duo Developer** session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe 'tracks different work items' do
    context 'when noteable is a merge request' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let(:noteable) { merge_request }

      it 'creates system note for merge request' do
        note = service.agent_session_started('123', 'User', 'Duo Developer')
        expect(note.noteable).to eq(merge_request)
        expect(note.project).to eq(project)
        expect(note.author).to eq(author)
      end
    end

    context 'when noteable is an Issue' do
      it 'creates system note for Issue' do
        note = service.agent_session_started('123', 'User', 'Duo Developer')
        expect(note.noteable).to eq(issue)
        expect(note.project).to eq(project)
        expect(note.author).to eq(author)
      end
    end
  end
end

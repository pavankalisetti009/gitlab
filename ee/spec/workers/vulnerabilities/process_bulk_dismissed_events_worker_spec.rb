# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessBulkDismissedEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:vulnerabilities) do
    create_list(:vulnerability, 3, :with_findings, :detected, :high_severity, project: project)
  end

  let_it_be(:vulnerability_ids) { vulnerabilities.map(&:id) }

  let(:comment) { "i prefer lowercase." }
  let(:dismissal_reason) { 'used_in_tests' }

  let(:bulk_dismissed_event) do
    ::Vulnerabilities::BulkDismissedEvent.new(data: {
      vulnerabilities: vulnerabilities.map do |vulnerability|
        {
          vulnerability_id: vulnerability.id,
          project_id: project.id,
          namespace_id: vulnerability.project.project_namespace_id,
          dismissal_reason: dismissal_reason,
          comment: comment,
          user_id: user.id
        }
      end
    })
  end

  subject(:use_event) { consume_event(subscriber: described_class, event: bulk_dismissed_event) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it 'inserts a system note for each vulnerability' do
    use_event

    notes = Note.last(3)

    expect(notes[0]).to have_attributes(
      noteable: vulnerabilities[0],
      author: user,
      project: project,
      namespace_id: project.project_namespace_id,
      note: "changed vulnerability status to Dismissed: " \
        "Used In Tests with the following comment: \"#{comment}\"")
    expect(notes[1]).to have_attributes(
      noteable: vulnerabilities[1],
      author: user,
      project: project,
      namespace_id: project.project_namespace_id,
      note: "changed vulnerability status to Dismissed: " \
        "Used In Tests with the following comment: \"#{comment}\"")
    expect(notes[2]).to have_attributes(
      noteable: vulnerabilities[2],
      author: user,
      project: project,
      namespace_id: project.project_namespace_id,
      note: "changed vulnerability status to Dismissed: " \
        "Used In Tests with the following comment: \"#{comment}\"")

    system_note_metadata = SystemNoteMetadata.last(3)
    expect(system_note_metadata[0]).to have_attributes(
      note_id: notes[0].id,
      action: "vulnerability_dismissed"
    )
    expect(system_note_metadata[1]).to have_attributes(
      note_id: notes[1].id,
      action: "vulnerability_dismissed"
    )
    expect(system_note_metadata[2]).to have_attributes(
      note_id: notes[2].id,
      action: "vulnerability_dismissed"
    )
  end

  it 'triggers webhook events for each vulnerability' do
    3.times do
      expect_next_found_instance_of(Vulnerability) do |found_vulnerability|
        expect(found_vulnerability).to receive(:trigger_webhook_event)
      end
    end

    use_event
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RemoveAllVulnerabilitiesWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerabilities) do
    create_list(
      :vulnerability,
      2,
      :with_findings,
      :with_state_transition,
      :with_notes,
      :with_issue_links,
      :with_user_mention,
      project: project
    )
  end

  describe "#perform" do
    let(:batch_size) { 1 }
    let(:worker) { described_class.new }

    before do
      stub_const("#{described_class}::BATCH_SIZE", batch_size)
    end

    include_examples 'an idempotent worker' do
      subject(:perform) { worker.perform(project.id) }

      it 'iterates over Vulnerabilities in batches' do
        expect(::Vulnerability).to receive(:transaction).twice

        perform
      end

      expected_counts = {
        Vulnerability => 2,
        Vulnerabilities::Finding => 10,
        Vulnerabilities::IssueLink => 4,
        Vulnerabilities::StateTransition => 2,
        VulnerabilityUserMention => 2
      }

      expected_counts.each do |model, count|
        it "removes all #{model} records" do
          expect { perform }.to change { model.count }.by(-count)
        end
      end
    end
  end
end

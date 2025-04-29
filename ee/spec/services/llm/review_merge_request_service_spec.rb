# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ReviewMergeRequestService, :saas, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:resource) { create(:merge_request, source_project: project, target_project: project, author: user) }

  let(:ai_review_merge_request_allowed?) { true }
  let(:current_user) { user }
  let(:options) { {} }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    let(:action_name) { :review_merge_request }
    let(:content) { 'Review merge request' }

    before_all do
      group.add_guest(user)
    end

    before do
      allow(resource)
        .to receive(:ai_review_merge_request_allowed?)
        .with(user)
        .and_return(ai_review_merge_request_allowed?)
      allow(user).to receive(:allowed_to_use?).with(:review_merge_request).and_return(true)
    end

    subject { described_class.new(current_user, resource, options).execute }

    context 'when duo_code_review_system_note feature flag is disabled' do
      it_behaves_like 'schedules completion worker' do
        let(:note) { instance_double Note, id: 123 }

        before do
          stub_feature_flags(duo_code_review_system_note: false)

          allow_next_instance_of(
            ::Notes::CreateService,
            project,
            Users::Internal.duo_code_review_bot,
            noteable: resource,
            note: Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest.review_queued_msg,
            system: false
          ) do |create_service|
            allow(create_service).to receive(:execute).and_return(note)
          end
        end

        let(:expected_options) { { progress_note_id: note.id } }

        subject { described_class.new(current_user, resource, options) }
      end
    end

    it_behaves_like 'schedules completion worker' do
      let(:note) { instance_double Note, id: 123 }

      before do
        allow_next_instance_of(
          ::Notes::CreateService,
          project,
          Users::Internal.duo_code_review_bot,
          noteable: resource,
          note: "is reviewing your merge request and will let you know when it's finished",
          system: true
        ) do |create_service|
          allow(create_service).to receive(:execute).and_return(note)
        end
      end

      let(:expected_options) { { progress_note_id: note.id } }

      subject { described_class.new(current_user, resource, options) }
    end

    context 'when user is not member of project group' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when resource is not a merge_request' do
      let(:resource) { create(:epic, group: group) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when user has no ability to ai_review_merge_request' do
      let(:ai_review_merge_request_allowed?) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end
  end
end

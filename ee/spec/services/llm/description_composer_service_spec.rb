# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::DescriptionComposerService, :saas, feature_category: :code_review_workflow do
  let_it_be_with_refind(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :public, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:options) { {} }

  subject(:service) { described_class.new(user, merge_request, options) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(description_composer: true, ai_features: true, experimental_features: true)

    allow(user).to receive(:can?).with("read_merge_request", merge_request).and_call_original
    allow(user).to receive(:can?).with("read_issue", issue).and_call_original
    allow(user).to receive(:can?).with(:access_duo_features, merge_request.project).and_call_original
    allow(user).to receive(:can?).with(:admin_all_resources).and_call_original

    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  describe '#execute' do
    before do
      allow(Llm::CompletionWorker).to receive(:perform_for)
    end

    context 'when the user is permitted to view the merge request' do
      before_all do
        group.add_developer(user)
      end

      before do
        allow(user)
          .to receive(:can?)
          .with(:access_description_composer, merge_request)
          .and_return(true)
        allow(user).to receive(:allowed_to_use?).with(:description_composer).and_return(true)
      end

      it_behaves_like 'schedules completion worker' do
        let(:action_name) { :description_composer }
        let(:resource) { merge_request }
      end
    end

    context 'when the user is not permitted to view the merge request' do
      before do
        allow(project).to receive(:member?).with(user).and_return(false)
      end

      it 'returns an error' do
        expect(service.execute).to be_error

        expect(Llm::CompletionWorker).not_to have_received(:perform_for)
      end
    end
  end

  describe '#valid?' do
    using RSpec::Parameterized::TableSyntax

    where(:access_description_composer, :issuable_type, :result) do
      true   | :merge_request | true
      false  | :merge_request | false
      true   | :issue         | false
      false  | :issue         | false
    end

    with_them do
      let(:issuable) do
        case issuable_type
        when :merge_request then merge_request
        when :issue then issue
        end
      end

      before_all do
        group.add_maintainer(user)
      end

      before do
        allow(user)
          .to receive(:can?)
          .with(:access_description_composer, issuable)
          .and_return(access_description_composer)
        allow(user).to receive(:allowed_to_use?).with(:description_composer).and_return(true)
      end

      it { expect(described_class.new(user, issuable, options).valid?).to eq(result) }
    end
  end
end

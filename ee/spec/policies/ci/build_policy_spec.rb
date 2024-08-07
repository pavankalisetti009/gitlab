# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildPolicy, feature_category: :continuous_integration do
  it_behaves_like 'a deployable job policy in EE', :ci_build

  describe 'troubleshoot_job_with_ai' do
    let(:authorized) { true }
    let(:cloud_connector_free_access) { true }
    let(:cloud_connector_user_access) { true }
    let_it_be(:project) { create(:project, :private) }
    let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project) }
    let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
    let_it_be(:user) { create(:user) }

    subject { described_class.new(user, build) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(ai_features: true, troubleshoot_job: true)
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(
        :resource, :allowed?).and_return(authorized)
      allow(user).to receive(:can?).with(:admin_all_resources).and_call_original
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
      allow(user).to receive(:can?).with(:access_duo_chat).and_return(true)
      allow(user).to receive(:can?).with(:access_duo_features, build.project).and_return(true)
      allow(::CloudConnector::AvailableServices).to receive(:find_by_name).with(:troubleshoot_job).and_return(
        instance_double(
          CloudConnector::BaseAvailableServiceData,
          free_access?: cloud_connector_free_access,
          allowed_for?: cloud_connector_user_access
        )
      )
    end

    context 'when feature is chat authorized' do
      subject { described_class.new(user, build) }

      let(:authorized) { true }

      it { is_expected.to be_allowed(:troubleshoot_job_with_ai) }

      context 'when user cannot read_build' do
        before_all do
          project.add_guest(user)
        end

        before do
          project.update_attribute(:public_builds, false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when the feature is not ai licensed' do
        before do
          stub_licensed_features(ai_features: false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when feature is not licensed for a project' do
        before do
          # Mock the project specifically because there was a bug where we used a global feature check
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when feature is licensed for a project' do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(true)
        end

        it { is_expected.to be_allowed(:troubleshoot_job_with_ai) }
      end
    end

    context 'when feature is not authorized' do
      let(:authorized) { false }

      it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
    end

    # TODO: remove these tests when implementing https://gitlab.com/gitlab-org/gitlab/-/issues/473087
    describe 'cloud connector' do
      using RSpec::Parameterized::TableSyntax
      where(:free_access, :user_access, :allowed) do
        true  | true  | true
        true  | false | true
        false | true  | true
        false | false | false
      end

      with_them do
        let(:cloud_connector_free_access) { free_access }
        let(:cloud_connector_user_access) { user_access }
        let(:policy) { :troubleshoot_job_with_ai }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'when on .org or .com', :saas do
      using RSpec::Parameterized::TableSyntax
      where(:group_with_ai_membership, :free_access, :user_access, :licensed, :allowed) do
        true  | true   | true  | true  | true
        true  | false  | true  | true  | true
        false | false  | true  | true  | true
        false | false  | false | true  | false
        true  | true   | false | true  | true
        false | true   | false | true  | false
        true  | true   | true  | false | false
        true  | false  | true  | false | false
        false | false  | true  | false | false
        false | false  | false | false | false
        true  | true   | false | false | false
        false | true   | false | false | false
      end

      with_them do
        before do
          allow(user).to receive(:any_group_with_ga_ai_available?).and_return(group_with_ai_membership)
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(licensed)
        end

        let(:cloud_connector_free_access) { free_access }
        let(:cloud_connector_user_access) { user_access }
        let(:policy) { :troubleshoot_job_with_ai }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end
end

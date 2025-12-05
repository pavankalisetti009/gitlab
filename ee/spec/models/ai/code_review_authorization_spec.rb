# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeReviewAuthorization, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:llm_authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
  let(:dap_validator) { instance_double(::Ai::DuoWorkflows::CodeReview::AvailabilityValidator) }

  before do
    stub_licensed_features(review_merge_request: true)

    allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(llm_authorizer)
    allow(llm_authorizer).to receive(:allowed?).and_return(true)

    allow(::Ai::DuoWorkflows::CodeReview::AvailabilityValidator).to receive(:new).and_return(dap_validator)
    allow(dap_validator).to receive(:available?).and_return(false)
  end

  shared_examples 'classic flow authorization' do
    context 'when feature is authorized' do
      before do
        allow(llm_authorizer).to receive(:allowed?).and_return(true)
      end

      it { is_expected.to be(false) }

      context 'when user has permission' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_ai_review_mr, expected_container).and_return(true)
        end

        it { is_expected.to be(true) }
      end

      context 'when license is not set' do
        before do
          stub_licensed_features(review_merge_request: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when feature is not authorized' do
      before do
        allow(llm_authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end

  shared_examples 'DAP flow takes precedence' do
    context 'when DAP is available' do
      before do
        allow(dap_validator).to receive(:available?).and_return(true)
        allow(Ability).to receive(:allowed?).and_return(false)
      end

      it 'returns true even if classic flow would deny' do
        expect(subject).to be(true)
      end

      it 'calls AvailabilityValidator with correct resource' do
        subject

        expect(::Ai::DuoWorkflows::CodeReview::AvailabilityValidator).to have_received(:new).with(
          user: user,
          resource: expected_validation_resource
        )
      end
    end

    context 'when DAP is not available' do
      before do
        allow(dap_validator).to receive(:available?).and_return(false)
      end

      it 'falls back to classic flow' do
        allow(Ability).to receive(:allowed?).with(user, :access_ai_review_mr, expected_container).and_return(true)
        allow(llm_authorizer).to receive(:allowed?).and_return(true)

        expect(subject).to be(true)
      end
    end
  end

  describe '#allowed?' do
    subject(:allowed?) { described_class.new(resource).allowed?(user) }

    context 'with Project resource' do
      let(:resource) { project }
      let(:expected_container) { project }
      let(:expected_validation_resource) { project }

      it_behaves_like 'classic flow authorization'
      it_behaves_like 'DAP flow takes precedence'
    end

    context 'with Group resource' do
      let(:resource) { group }
      let(:expected_container) { group }
      let(:expected_validation_resource) { group }

      it_behaves_like 'classic flow authorization'
      it_behaves_like 'DAP flow takes precedence'
    end

    context 'with MergeRequest resource' do
      let(:resource) { merge_request }
      let(:expected_container) { project }
      let(:expected_validation_resource) { project }

      it_behaves_like 'classic flow authorization'
      it_behaves_like 'DAP flow takes precedence'

      it 'uses the merge request project for authorization' do
        allow(Ability).to receive(:allowed?).with(user, :access_ai_review_mr, project).and_return(true)
        allow(llm_authorizer).to receive(:allowed?).and_return(true)

        expect(allowed?).to be(true)
        expect(::Gitlab::Llm::FeatureAuthorizer).to have_received(:new).with(
          container: project,
          feature_name: :review_merge_request,
          user: user
        )
      end
    end
  end
end

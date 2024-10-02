# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::ProgressService, feature_category: :onboarding do
  describe '#execute' do
    let(:namespace) { create(:namespace) }
    let(:action) { :merge_request_created }

    subject(:execute_service) { described_class.new(namespace).execute(action: action) }

    context 'when the namespace is a root' do
      before do
        Onboarding::Progress.onboard(namespace)
      end

      it 'registers a namespace onboarding progress action for the given namespace' do
        execute_service

        expect(Onboarding::Progress.completed?(namespace, action)).to eq(true)
      end
    end

    context 'when the namespace is not the root' do
      let(:group) { create(:group, :nested) }

      before do
        Onboarding::Progress.onboard(group)
      end

      it 'does not register a namespace onboarding progress action' do
        execute_service

        expect(Onboarding::Progress.completed?(group, action)).to be(false)
      end
    end

    context 'when no namespace is passed' do
      let(:namespace) { nil }

      it 'does not register a namespace onboarding progress action' do
        execute_service

        expect(Onboarding::Progress.completed?(namespace, action)).to be(false)
      end
    end
  end
end

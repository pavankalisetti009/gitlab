# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::AutoBanService, feature_category: :instance_resiliency do
  let_it_be_with_reload(:user) { create(:user) }
  let(:reason) { 'reason' }
  let(:service) { described_class.new(user: user, reason: reason) }

  shared_examples 'executing the service' do
    context 'when the feature is enabled' do
      it 'executes the Arkose truth data service' do
        expect_next_instance_of(Arkose::TruthDataService, user: user, is_legit: false) do |instance|
          expect(instance).to receive(:execute)
        end

        subject
      end
    end

    context 'when the feature is not enabled' do
      before do
        stub_feature_flags(arkose_truth_data_auto_ban: false)
      end

      it 'does not execute the arkose truth data service' do
        expect(Arkose::TruthDataService).not_to receive(:new)

        subject
      end
    end
  end

  describe '#execute' do
    subject { service.execute }

    it_behaves_like 'executing the service'
  end

  describe '#execute!' do
    subject { service.execute! }

    it_behaves_like 'executing the service'
  end
end

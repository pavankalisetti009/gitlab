# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AddOns::DiscoverDuoProHelper, feature_category: :onboarding do
  describe '#duo_pro_trial_status_track_action' do
    let(:namespace) { build_stubbed(:namespace) }

    subject(:track_action_tag) { helper.duo_pro_trial_status_track_action(namespace) }

    context 'when an active trial DuoPro add-on purchase exists' do
      before do
        allow(GitlabSubscriptions::DuoPro).to receive(:active_trial_add_on_purchase_for_namespace?)
          .with(namespace).and_return(true)
      end

      it { is_expected.to eq('click_documentation_link_duo_pro_trial_active') }
    end

    context 'when no active trial DuoPro add-on purchase exists' do
      before do
        allow(GitlabSubscriptions::DuoPro).to receive(:active_trial_add_on_purchase_for_namespace?)
          .with(namespace).and_return(false)
      end

      it { is_expected.to eq('click_documentation_link_duo_pro_trial_expired') }
    end
  end

  describe '#duo_pro_discover_card_collection' do
    let(:namespace) { build_stubbed(:namespace) }

    subject(:card_collection) { helper.duo_pro_discover_card_collection(namespace) }

    it 'returns an array of hashes' do
      expect(card_collection).to be_an(Array)
      expect(card_collection).to all(be_a(Hash))
    end

    it 'returns the correct number of cards' do
      expect(card_collection.size).to eq(4)
    end

    it 'includes the required keys for each card' do
      expect(card_collection).to all(include(:header, :body))
    end

    it 'includes the correct headers' do
      headers = card_collection.pluck(:header)
      expect(headers).to contain_exactly(
        s_("DuoProDiscover|Accelerate your path to market"),
        s_("DuoProDiscover|Adopt AI with guardrails"),
        s_("DuoProDiscover|Improve developer experience"),
        s_("DuoProDiscover|Committed to transparent AI")
      )
    end

    it 'includes the AI Transparency Center link in the last card' do
      last_card = card_collection.last
      expect(last_card[:body]).to include('AI Transparency Center')
      expect(last_card[:body]).to include('https://about.gitlab.com/ai-transparency-center/')
    end
  end
end

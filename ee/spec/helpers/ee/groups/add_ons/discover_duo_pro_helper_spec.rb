# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AddOns::DiscoverDuoProHelper, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }

  shared_context 'with active trial' do
    before do
      allow(GitlabSubscriptions::DuoPro).to receive(:active_trial_add_on_purchase_for_namespace?)
        .with(namespace).and_return(true)
    end
  end

  shared_context 'without active trial' do
    before do
      allow(GitlabSubscriptions::DuoPro).to receive(:active_trial_add_on_purchase_for_namespace?)
        .with(namespace).and_return(false)
    end
  end

  describe '#duo_pro_documentation_link_track_action' do
    subject { helper.duo_pro_documentation_link_track_action(namespace) }

    context 'when an active trial DuoPro add-on purchase exists' do
      include_context 'with active trial'

      it { is_expected.to eq('click_documentation_link_duo_pro_trial_active') }
    end

    context 'when no active trial DuoPro add-on purchase exists' do
      include_context 'without active trial'

      it { is_expected.to eq('click_documentation_link_duo_pro_trial_expired') }
    end
  end

  describe '#duo_pro_discover_card_collection' do
    subject(:card_collection) { helper.duo_pro_discover_card_collection(namespace) }

    it 'returns an array of hashes with correct structure and content' do
      expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
      expect(card_collection.size).to eq(4)
      expect(card_collection).to all(include(:header, :body))

      headers = card_collection.pluck(:header)
      expect(headers).to contain_exactly(
        s_("DuoProDiscover|Accelerate your path to market"),
        s_("DuoProDiscover|Adopt AI with guardrails"),
        s_("DuoProDiscover|Improve developer experience"),
        s_("DuoProDiscover|Committed to transparent AI")
      )

      last_card = card_collection.last
      expect(last_card[:body]).to include('AI Transparency Center')
      expect(last_card[:body]).to include('https://about.gitlab.com/ai-transparency-center/')
      expect(last_card[:body]).to include(
        helper.duo_pro_documentation_link_track_action(namespace)
      )
    end
  end

  describe '#duo_pro_whats_new_card_collection' do
    subject(:card_collection) { helper.duo_pro_whats_new_card_collection(namespace) }

    it 'returns an array of hashes with correct structure and content' do
      expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
      expect(card_collection.size).to eq(4)
      expect(card_collection).to all(include(:header, :body, :link_text, :link_path, :track_label, :track_action))

      headers = card_collection.pluck(:header)
      expect(headers).to contain_exactly(
        s_("DuoProDiscover|Test generation"),
        s_("DuoProDiscover|Code explanation"),
        s_("DuoProDiscover|Code refactoring"),
        s_("DuoProDiscover|Chat from any location")
      )

      track_actions = card_collection.pluck(:track_action)
      expect(track_actions).to all(eq(helper.duo_pro_documentation_link_track_action(namespace)))
    end
  end
end

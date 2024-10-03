# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AddOns::DiscoverDuoProHelper, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }

  shared_examples 'trial status' do |status, expected_action|
    before do
      allow(GitlabSubscriptions::Trials::DuoPro).to receive(:active_add_on_purchase_for_namespace?)
        .with(namespace).and_return(status)
    end

    it 'returns correct values' do
      expect(helper.duo_pro_documentation_link_track_action(namespace)).to eq(expected_action)
    end
  end

  describe 'trial status methods' do
    context 'with active trial' do
      it_behaves_like 'trial status', true, 'click_documentation_link_duo_pro_trial_active', 'active'
    end

    context 'without active trial' do
      it_behaves_like 'trial status', false, 'click_documentation_link_duo_pro_trial_expired', 'expired'
    end
  end

  describe 'card collection methods' do
    describe '#duo_pro_discover_card_collection' do
      subject(:card_collection) { helper.duo_pro_discover_card_collection(namespace) }

      it 'returns correct card structure', :aggregate_failures do
        expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
        expect(card_collection.size).to eq(4)
        expect(card_collection).to all(include(:header, :body))

        headers = card_collection.pluck(:header)
        expected_headers = [
          s_('DuoProDiscover|Privacy-first AI'),
          s_('DuoProDiscover|Boost team collaboration'),
          s_('DuoProDiscover|Improve developer experience'),
          s_('DuoProDiscover|Transparent AI')
        ]
        expect(headers).to contain_exactly(*expected_headers)

        last_card = card_collection.last
        expect(last_card[:body]).to include('AI Transparency Center')
        expect(last_card[:body]).to include('https://about.gitlab.com/ai-transparency-center/')
        expect(last_card[:body]).to include(helper.duo_pro_documentation_link_track_action(namespace))
      end
    end

    describe '#duo_pro_core_section_one_card_collection' do
      subject(:card_collection) { helper.duo_pro_core_section_one_card_collection(namespace) }

      it 'returns correct card structure', :aggregate_failures do
        expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
        expect(card_collection.size).to eq(4)
        expect(card_collection).to all(include(:header, :body, :footer))

        headers = card_collection.pluck(:header)
        expected_headers = [
          s_('DuoProDiscover|Boost productivity with smart code assistance'),
          s_('DuoProDiscover|Real-time guidance'),
          s_('DuoProDiscover|Automate mundane tasks'),
          s_('Duo ProDiscover|Modernize code faster')
        ]
        expect(headers).to contain_exactly(*expected_headers)

        footers = card_collection.pluck(:footer)
        expect(footers).to all(be_html_safe)
      end
    end
  end

  describe '#render_footer_link' do
    let(:link_path) { '/test/path' }
    let(:link_text) { 'Test Link' }
    let(:track_action) { 'test_action' }
    let(:track_label) { 'test_label' }

    subject(:rendered_link) do
      helper.render_footer_link(
        link_path: link_path,
        link_text: link_text,
        track_action: track_action,
        track_label: track_label
      )
    end

    it 'renders a link with correct attributes', :aggregate_failures do
      expect(rendered_link).to be_html_safe
      expect(rendered_link).to have_link(link_text, href: link_path)
      expect(rendered_link).to have_css('a.gl-link[target="_blank"][rel="noopener noreferrer"]')
      expect(rendered_link).to have_css("a[data-track-action='#{track_action}'][data-track-label='#{track_label}']")
    end
  end
end

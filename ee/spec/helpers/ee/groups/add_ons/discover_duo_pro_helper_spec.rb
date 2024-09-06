# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AddOns::DiscoverDuoProHelper, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }

  shared_examples 'trial status' do |status, expected_action|
    before do
      allow(GitlabSubscriptions::DuoPro).to receive(:active_trial_add_on_purchase_for_namespace?)
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
        expect(headers).to contain_exactly(
          s_("DuoProDiscover|Accelerate your path to market"),
          s_("DuoProDiscover|Adopt AI with guardrails"),
          s_("DuoProDiscover|Improve developer experience"),
          s_("DuoProDiscover|Committed to transparent AI")
        )

        last_card = card_collection.last
        expect(last_card[:body]).to include('AI Transparency Center')
        expect(last_card[:body]).to include('https://about.gitlab.com/ai-transparency-center/')
        expect(last_card[:body]).to include(helper.duo_pro_documentation_link_track_action(namespace))
      end
    end

    describe '#duo_pro_whats_new_card_collection' do
      subject(:card_collection) { helper.duo_pro_whats_new_card_collection(namespace) }

      it 'returns correct card structure', :aggregate_failures do
        expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
        expect(card_collection.size).to eq(4)
        expect(card_collection).to all(include(:header, :body, :footer))

        headers = card_collection.pluck(:header)
        expect(headers).to contain_exactly(
          s_("DuoProDiscover|Test Generation"),
          s_("DuoProDiscover|Code Explanation"),
          s_("DuoProDiscover|Code Refactoring"),
          s_("DuoProDiscover|Chat from any location")
        )

        footers = card_collection.pluck(:footer)
        expect(footers).to all(be_html_safe)
        expect(footers).to all(include(helper.duo_pro_documentation_link_track_action(namespace)))
      end
    end

    describe '#duo_pro_code_suggestions_card_collection' do
      subject(:card_collection) { helper.duo_pro_code_suggestions_card_collection(namespace) }

      it 'returns correct card structure', :aggregate_failures do
        expect(card_collection).to be_an(Array).and(all(be_a(Hash)))
        expect(card_collection.size).to eq(3)
        expect(card_collection).to all(include(:header, :body))

        headers = card_collection.pluck(:header)
        expect(headers).to contain_exactly(
          s_("DuoProDiscover|Code generation"),
          s_("DuoProDiscover|Code completion"),
          s_("DuoProDiscover|Language and IDE support")
        )

        expect(card_collection[0][:footer]).to be_html_safe
        expect(card_collection[0][:footer]).to include('data-track-label="code_generation_feature"')
        expect(card_collection[0][:footer]).to include(helper.duo_pro_documentation_link_track_action(namespace))
        expect(card_collection[0][:footer]).to include(s_("DuoProDiscover|Read documentation"))
        expect(card_collection[0][:footer]).to include(
          'href="/help/user/project/repository/code_suggestions#use-code-suggestions"'
        )

        expect(card_collection[1][:footer]).to be_html_safe
        expect(card_collection[1][:footer]).to include('data-track-label="code_completion_feature"')
        expect(card_collection[1][:footer]).to include(helper.duo_pro_documentation_link_track_action(namespace))
        expect(card_collection[1][:footer]).to include(s_("DuoProDiscover|Launch Demo"))
        expect(card_collection[1][:footer]).to include('href="https://gitlab.navattic.com/code-suggestions"')

        expect(card_collection[2]).not_to include(:footer)
      end
    end
  end

  describe '#render_footer_link' do
    let(:link_path) { '/test/path' }
    let(:link_text) { 'Test Link' }
    let(:track_action) { 'test_action' }
    let(:track_label) { 'test_label' }
    let(:icon) { 'external-link' }

    subject(:rendered_link) do
      helper.render_footer_link(
        link_path: link_path,
        link_text: link_text,
        track_action: track_action,
        track_label: track_label,
        icon: icon
      )
    end

    it 'renders a link with correct attributes', :aggregate_failures do
      expect(rendered_link).to be_html_safe
      expect(rendered_link).to have_link(link_text, href: link_path)
      expect(rendered_link).to have_css('a.gl-link[target="_blank"][rel="noopener noreferrer"]')
      expect(rendered_link).to have_css("a[data-track-action='#{track_action}'][data-track-label='#{track_label}']")
      expect(rendered_link).to have_css("svg.gl-icon.gl-ml-2")
    end

    context 'when icon is not provided' do
      let(:icon) { nil }

      it 'does not include the icon' do
        expect(rendered_link).not_to have_css('svg.gl-icon')
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '"Explore" navbar (EE)', :js, feature_category: :navigation do
  let(:ai_catalog_available) { true }

  before do
    allow(Ai::Catalog).to receive(:available?).and_return(ai_catalog_available)
    visit explore_root_path
  end

  it 'shows AI Catalog menu item' do
    within_testid('non-static-items-section') do
      expect(page).to have_text('AI Catalog')
    end
  end

  context 'when AI Catalog is not available for the instance' do
    let(:ai_catalog_available) { false }

    it 'does not show AI Catalog menu item' do
      within_testid('non-static-items-section') do
        expect(page).not_to have_text('AI Catalog')
      end
    end
  end
end

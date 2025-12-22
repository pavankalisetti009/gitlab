# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NavHelper, feature_category: :navigation do
  let(:user) { build_stubbed(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#extra_top_bar_classes' do
    context 'when top_bar_duo_button_enabled? returns true' do
      before do
        allow(helper).to receive(:top_bar_duo_button_enabled?).and_return(true)
      end

      it 'returns the correct CSS classes' do
        expect(helper.extra_top_bar_classes).to eq('gl-group top-bar-duo-button-present')
      end
    end

    context 'when top_bar_duo_button_enabled? returns false' do
      before do
        allow(helper).to receive(:top_bar_duo_button_enabled?).and_return(false)
      end

      it 'returns nil' do
        expect(helper.extra_top_bar_classes).to be_nil
      end
    end
  end
end

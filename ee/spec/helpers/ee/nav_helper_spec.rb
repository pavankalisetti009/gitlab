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

  describe '#top_bar_duo_button_enabled?' do
    before do
      skip 'Test not applicable in new UI' if Users::ProjectStudio.enabled_for_user?(user)
    end

    context 'when TanukiBot.show_breadcrumbs_entry_point? returns true' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:show_breadcrumbs_entry_point?).with(user: user).and_return(true)
      end

      it 'returns true' do
        expect(helper).to be_top_bar_duo_button_enabled
      end
    end

    context 'when TanukiBot.show_breadcrumbs_entry_point? returns false' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:show_breadcrumbs_entry_point?).with(user: user).and_return(false)
      end

      it 'returns false' do
        expect(helper).not_to be_top_bar_duo_button_enabled
      end
    end

    context 'when current_user is nil' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
        allow(::Gitlab::Llm::TanukiBot).to receive(:show_breadcrumbs_entry_point?).with(user: nil).and_return(false)
      end

      it 'returns false' do
        expect(helper).not_to be_top_bar_duo_button_enabled
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::PinsController, feature_category: :navigation do
  let(:user) { create(:user) }
  let(:panel) { 'project' }
  let(:menu_item_ids) { %w[item4 item7] }

  before do
    user.update!(pinned_nav_items: { panel => ['item4'] })
    sign_in(user)
  end

  describe 'PUT /-/users/pins' do
    context 'for experiment', :experiment do
      let(:exp) { instance_double(ApplicationExperiment) }

      before do
        allow_next_instance_of(described_class) do |controller|
          allow(controller).to receive(:experiment)
                                 .with(:default_pinned_nav_items, actor: user)
                                 .and_return(exp)
        end
      end

      it 'tracks event for pinning nav items' do
        expect(exp).to receive(:track).with(:pin_menu_item, label: 'item7')

        put pins_path, params: { panel: panel, menu_item_ids: menu_item_ids }
      end

      it 'tracks event for unpinning nav items' do
        expect(exp).to receive(:track).with(:unpin_menu_item, label: 'item4')

        put pins_path, params: { panel: panel, menu_item_ids: [] }
      end
    end
  end
end

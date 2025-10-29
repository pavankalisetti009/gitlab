# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_agent_platform do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }

  subject(:menu) { described_class.new(context) }

  describe '#configure_menu_items' do
    using RSpec::Parameterized::TableSyntax

    where(:ai_catalog, :ai_catalog_flows_ff, :duo_workflow_permission, :configure_result, :expected_items) do
      true  | true  | true  | true  | [:ai_flows]
      true  | true  | false | false | []
      true  | false | true  | false | []
      false | true  | true  | false | []
    end

    with_them do
      before do
        stub_feature_flags(global_ai_catalog: ai_catalog)
        stub_feature_flags(ai_catalog_flows: ai_catalog_flows_ff)
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(duo_workflow_permission)
      end

      it "returns correct configure result" do
        expect(menu.configure_menu_items).to eq(configure_result)
      end

      it "renders expected menu items" do
        expect(menu.renderable_items.size).to eq(expected_items.size)
        expect(menu.renderable_items.map(&:item_id)).to match_array(expected_items)
      end
    end
  end

  describe '#title' do
    it 'returns correct title' do
      expect(menu.title).to eq('Automate')
    end
  end

  describe '#sprite_icon' do
    it 'returns correct icon' do
      expect(menu.sprite_icon).to eq('tanuki-ai')
    end
  end

  describe 'flows menu item' do
    before do
      allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(true)

      menu.configure_menu_items
    end

    let(:flows_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flows } }

    it 'has correct title' do
      expect(flows_menu_item.title).to eq('Flows')
    end

    it 'has correct link' do
      expect(flows_menu_item.link).to eq("/groups/#{group.full_path}/-/automate/flows")
    end

    it 'has correct active routes' do
      expect(flows_menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(flows_menu_item.item_id).to eq(:ai_flows)
    end
  end
end

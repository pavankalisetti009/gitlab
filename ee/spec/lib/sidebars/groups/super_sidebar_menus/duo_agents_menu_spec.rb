# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_agent_platform do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }

  subject(:menu) { described_class.new(context) }

  describe '#configure_menu_items' do
    using RSpec::Parameterized::TableSyntax

    where(:ai_catalog, :read_flow_permission, :duo_workflow_permission, :configure_result,
      :expected_items) do
      true  | true  | true  | true  | [:ai_agents, :ai_flows]
      true  | true  | false | false | []
      true  | false | true  | true  | [:ai_agents]
      false | true  | true  | false | []
    end

    with_them do
      before do
        stub_feature_flags(global_ai_catalog: ai_catalog)
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(duo_workflow_permission)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(read_flow_permission)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow,
          group).and_return(read_flow_permission)
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
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(true)

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

    context 'when user has read_ai_foundational_flow but not read_ai_catalog_flow permission' do
      before do
        stub_feature_flags(global_ai_catalog: true)
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, group).and_return(true)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, group).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, group).and_return(true)

        menu.configure_menu_items
      end

      it 'still shows the flows menu item' do
        flows_menu_item = menu.renderable_items.find { |item| item.item_id == :ai_flows }
        expect(flows_menu_item).not_to be_nil
        expect(flows_menu_item.title).to eq('Flows')
      end
    end

    context 'when user has neither read_ai_foundational_flow nor read_ai_catalog_flow permission' do
      let(:configured_menu) { described_class.new(context) }

      before do
        stub_feature_flags(global_ai_catalog: true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(false)

        configured_menu.configure_menu_items
      end

      it 'does not show the flows menu item' do
        flows_menu_item = configured_menu.renderable_items.find { |item| item.item_id == :ai_flows }
        expect(flows_menu_item).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_agent_platform do
  let_it_be(:project) { build(:project) }
  let_it_be(:user) { build(:user) }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  subject(:menu) { described_class.new(context) }

  describe '#configure_menu_items' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_features_enabled, :duo_workflow_in_ci_ff, :duo_remote_flows_enabled, :can_manage_ai_flow_triggers,
      :ai_catalog, :ai_catalog_flows_ff, :ai_catalog_third_party_flows_ff, :configure_result, :expected_items) do
      true  | true  | true  | false | false | false | false | true  | [:agents_runs]
      true  | true  | true  | true  | false | false | false | true  | [:agents_runs, :ai_flow_triggers]
      true  | true  | true  | true  | true  | true  | false | true  | [:agents_runs, :ai_catalog_agents,
        :ai_flow_triggers, :ai_flows]
      true  | true  | true  | true  | true  | false | true  | true  | [:agents_runs, :ai_catalog_agents,
        :ai_flow_triggers, :ai_flows]
      true  | true  | true  | true  | true  | true  | true  | true  | [:agents_runs, :ai_catalog_agents,
        :ai_flow_triggers, :ai_flows]
      true  | true  | true  | true  | true  | false | false | true  | [:agents_runs, :ai_catalog_agents,
        :ai_flow_triggers]
      true  | true  | false | false | false | false | false | false | []
      true  | true  | false | true  | true  | true  | false | true  | [:ai_catalog_agents, :ai_flow_triggers, :ai_flows]
      true  | true  | false | true  | true  | false | true  | true  | [:ai_catalog_agents, :ai_flow_triggers, :ai_flows]
      true  | false | true  | false | true  | true  | false | true  | [:ai_catalog_agents, :ai_flows]
      true  | false | true  | false | true  | false | true  | true  | [:ai_catalog_agents, :ai_flows]
      true  | false | true  | false | false | false | false | false | []
      true  | false | true  | true  | false | false | false | true  | [:ai_flow_triggers]
      true  | false | false | false | false | false | false | false | []
      true  | false | false | true  | false | false | false | true  | [:ai_flow_triggers]
      false | true  | true  | false | false | false | false | false | []
      false | true  | true  | true  | false | false | false | false | []
      false | true  | true  | true  | true  | true  | false | false | []
      false | true  | false | false | false | false | false | false | []
      false | true  | false | true  | true  | false | false | false | []
      false | false | true  | false | true  | false | false | false | []
      false | false | true  | false | false | false | false | false | []
      false | false | true  | true  | false | false | false | false | []
      false | false | false | false | false | false | false | false | []
      false | false | false | true  | false | false | false | false | []
    end

    with_them do
      before do
        stub_feature_flags(duo_workflow_in_ci: duo_workflow_in_ci_ff)
        stub_feature_flags(global_ai_catalog: ai_catalog)
        stub_feature_flags(ai_catalog_flows: ai_catalog_flows_ff)
        stub_feature_flags(ai_catalog_third_party_flows: ai_catalog_third_party_flows_ff)
        project.project_setting.update!(
          duo_remote_flows_enabled: duo_remote_flows_enabled,
          duo_features_enabled: duo_features_enabled
        )
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(can_manage_ai_flow_triggers)
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      end

      it "returns correct configure result" do
        expect(menu.configure_menu_items).to eq(configure_result)
      end

      it "renders expected menu items" do
        expect(menu.renderable_items.size).to eq(expected_items.size)

        if expected_items.any?
          expect(menu.renderable_items.map(&:item_id)).to match_array(expected_items)
        else
          expect(menu.renderable_items).to be_empty
        end
      end
    end
  end

  describe "when user does not have `duo_workflow` ability" do
    before do
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(true)
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(false)
    end

    it('does not render any menu items') do
      expect(menu.configure_menu_items).to be false
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

  describe 'agents runs menu item' do
    before do
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)

      project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)
      menu.configure_menu_items
    end

    let(:menu_item) { menu.renderable_items.first }

    it 'has correct title' do
      expect(menu_item.title).to eq('Agent sessions')
    end

    it 'has correct link' do
      expect(menu_item.link).to eq("/#{project.full_path}/-/automate/agent-sessions")
    end

    it 'has correct active routes' do
      expect(menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(menu_item.item_id).to eq(:agents_runs)
    end
  end

  describe 'flow triggers menu item' do
    context 'when user can manage ai flow triggers' do
      before do
        project.project_setting.update!(duo_features_enabled: true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(true)
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        menu.configure_menu_items
      end

      let(:flow_triggers_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flow_triggers } }

      it 'has correct title' do
        expect(flow_triggers_menu_item.title).to eq('Flow triggers')
      end

      it 'has correct link' do
        expect(flow_triggers_menu_item.link).to eq("/#{project.full_path}/-/automate/flow-triggers")
      end

      it 'has correct active routes' do
        expect(flow_triggers_menu_item.active_routes).to be_nil
      end

      it 'has correct item id' do
        expect(flow_triggers_menu_item.item_id).to eq(:ai_flow_triggers)
      end
    end

    context 'when user cannot manage ai flow triggers' do
      before do
        project.project_setting.update!(duo_features_enabled: true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        menu.configure_menu_items
      end

      it 'does not render flow triggers menu item' do
        flow_triggers_menu_item = menu.renderable_items.find { |item| item.item_id == :ai_flow_triggers }
        expect(flow_triggers_menu_item).to be_nil
      end
    end
  end

  describe 'flows menu item' do
    before do
      project.project_setting.update!(duo_features_enabled: true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)

      menu.configure_menu_items
    end

    let(:flows_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flows } }

    it 'has correct title' do
      expect(flows_menu_item.title).to eq('Flows')
    end

    it 'has correct link' do
      expect(flows_menu_item.link).to eq("/#{project.full_path}/-/automate/flows")
    end

    it 'has correct active routes' do
      expect(flows_menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(flows_menu_item.item_id).to eq(:ai_flows)
    end
  end
end

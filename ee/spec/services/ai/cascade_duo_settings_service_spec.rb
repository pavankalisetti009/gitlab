# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CascadeDuoSettingsService, feature_category: :ai_abstraction_layer do
  let(:setting_attributes) { { 'duo_features_enabled' => true } }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:group2) { create(:group) }
  let_it_be_with_reload(:subgroup2) { create(:group, parent: group2) }
  let_it_be_with_reload(:project2) { create(:project, :repository, group: group2) }

  subject(:service) { described_class.new(setting_attributes, current_user: user) }

  describe '#cascade_for_group' do
    context 'when updating invalid setting value' do
      let(:setting_attributes) do
        { 'invalid_setting_key' => 'invalid_setting_value', 'duo_remote_flows_enabled' => true }
      end

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when duo_features_enabled is true' do
      it 'updates subgroups and projects for given group to true' do
        # Initialize with duo_features_enabled: false
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: false) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: false) }

        service.cascade_for_group(group2)
        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(true)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(true)
      end
    end

    context 'when duo_features_enabled is false' do
      let(:setting_attributes) { { duo_features_enabled: false } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates subgroups and projects for given groups to false' do
        # Initialize with duo_features_enabled: true
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: true) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: true) }

        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(false)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(false)
      end
    end

    context 'when duo_foundational_flows_enabled is true' do
      let(:setting_attributes) { { 'duo_foundational_flows_enabled' => true } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates subgroups and projects for given group to true' do
        # Initialize with duo_foundational_flows_enabled: false
        [group2, subgroup2, group, subgroup].each do |g|
          g.namespace_settings.update!(duo_foundational_flows_enabled: false)
        end
        [project2, project].each { |p| p.project_setting.update!(duo_foundational_flows_enabled: false) }

        service.cascade_for_group(group2)
        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(group.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(project2.project_setting.duo_foundational_flows_enabled).to be(true)
        expect(project.project_setting.duo_foundational_flows_enabled).to be(true)
      end

      it 'schedules worker to sync flows' do
        expect(Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker)
          .to receive(:perform_async).with(group.id, user.id, nil)

        service.cascade_for_group(group)
      end

      context 'when there is no current_user' do
        let(:user) { nil }

        it 'schedules worker to sync flows' do
          expect(Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker)
            .to receive(:perform_async).with(group.id, nil, nil)

          service.cascade_for_group(group)
        end
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      let(:setting_attributes) { { 'duo_foundational_flows_enabled' => false } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates subgroups and projects for given groups to false' do
        # Initialize with duo_foundational_flows_enabled: true
        [group2, subgroup2, group, subgroup].each do |g|
          g.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end
        [project2, project].each { |p| p.project_setting.update!(duo_foundational_flows_enabled: true) }

        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(group.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(project2.project_setting.duo_foundational_flows_enabled).to be(true)
        expect(project.project_setting.duo_foundational_flows_enabled).to be(false)
      end

      it 'schedules worker to sync flows' do
        expect(Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker)
          .to receive(:perform_async).with(group.id, user.id, nil)

        service.cascade_for_group(group)
      end
    end

    context 'when enabled_foundational_flows is provided' do
      let_it_be(:flow1) do
        create(:ai_catalog_item, :with_foundational_flow_reference, public: true,
          organization: group.organization, foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:flow2) do
        create(:ai_catalog_item, :with_foundational_flow_reference, public: true,
          organization: group.organization, foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let(:flow_ids) { [flow1.id, flow2.id] }
      let(:flow_references) { [flow1.foundational_flow_reference, flow2.foundational_flow_reference] }
      let(:setting_attributes) { { 'enabled_foundational_flows' => flow_references } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'syncs flows for parent group, descendants, and projects' do
        service.cascade_for_group(group)

        expect(group.reload.enabled_foundational_flow_records.pluck(:catalog_item_id)).to match_array(flow_ids)
        expect(subgroup.reload.enabled_foundational_flow_records.pluck(:catalog_item_id)).to match_array(flow_ids)
        expect(project.reload.enabled_foundational_flow_records.pluck(:catalog_item_id)).to match_array(flow_ids)
      end

      it 'schedules worker to sync flows' do
        expect(Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker)
          .to receive(:perform_async).with(group.id, user.id, flow_references)

        service.cascade_for_group(group)
      end

      it 'handles empty flow array' do
        group.sync_enabled_foundational_flows!([flow1.id])
        subgroup.sync_enabled_foundational_flows!([flow1.id])
        project.sync_enabled_foundational_flows!([flow1.id])

        service = described_class.new({ 'enabled_foundational_flows' => [] }, current_user: user)
        service.cascade_for_group(group)

        expect(group.reload.enabled_foundational_flow_records).to be_empty
        expect(subgroup.reload.enabled_foundational_flow_records).to be_empty
        expect(project.reload.enabled_foundational_flow_records).to be_empty
      end
    end
  end

  describe '#cascade_for_instance' do
    context 'when duo_features_enabled is true' do
      let(:setting_attributes) { { 'duo_features_enabled' => true } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_features_enabled: false
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: false) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: false) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(true)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(true)
      end
    end

    context 'when duo_features_enabled is false' do
      let(:setting_attributes) { { 'duo_features_enabled' => false } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_features_enabled: true
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: true) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: true) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(false)
        expect(group.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(false)
        expect(project2.project_setting.duo_features_enabled).to be(false)
        expect(project.project_setting.duo_features_enabled).to be(false)
      end
    end

    context 'when duo_foundational_flows_enabled is true' do
      let(:setting_attributes) { { 'duo_foundational_flows_enabled' => true } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_foundational_flows_enabled: false
        [group2, subgroup2, group, subgroup].each do |g|
          g.namespace_settings.update!(duo_foundational_flows_enabled: false)
        end
        [project2, project].each { |p| p.project_setting.update!(duo_foundational_flows_enabled: false) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(group.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_foundational_flows_enabled).to be(true)
        expect(project2.project_setting.duo_foundational_flows_enabled).to be(true)
        expect(project.project_setting.duo_foundational_flows_enabled).to be(true)
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      let(:setting_attributes) { { 'duo_foundational_flows_enabled' => false } }

      subject(:service) { described_class.new(setting_attributes, current_user: user) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_foundational_flows_enabled: true
        [group2, subgroup2, group, subgroup].each do |g|
          g.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end
        [project2, project].each { |p| p.project_setting.update!(duo_foundational_flows_enabled: true) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(group.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(subgroup.namespace_settings.duo_foundational_flows_enabled).to be(false)
        expect(project2.project_setting.duo_foundational_flows_enabled).to be(false)
        expect(project.project_setting.duo_foundational_flows_enabled).to be(false)
      end
    end
  end
end

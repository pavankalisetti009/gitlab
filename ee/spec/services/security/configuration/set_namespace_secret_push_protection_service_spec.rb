# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetNamespaceSecretPushProtectionService, feature_category: :secret_detection do
  describe '#execute' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:mid_level_group) { create(:group, parent: top_level_group) }
    let_it_be(:bottom_level_group) { create(:group, parent: mid_level_group) }

    let_it_be_with_reload(:top_level_group_project) { create(:project, namespace: top_level_group) }
    let_it_be_with_reload(:mid_level_group_project) { create(:project, namespace: mid_level_group) }
    let_it_be_with_reload(:bottom_level_group_project) { create(:project, namespace: bottom_level_group) }
    let_it_be_with_reload(:excluded_project) { create(:project, namespace: mid_level_group) }

    context 'when namespace is a group' do
      let(:projects_to_change) { [top_level_group_project, mid_level_group_project, bottom_level_group_project] }

      it 'changes the attribute for nested projects' do
        projects_to_change.each do |project|
          security_setting = project.security_setting

          expect do
            described_class
              .execute(namespace: top_level_group, enable: true, excluded_projects_ids: [excluded_project.id])
          end.to change { security_setting.reload.pre_receive_secret_detection_enabled }.from(false).to(true)

          expect do
            described_class
              .execute(namespace: top_level_group, enable: true, excluded_projects_ids: [excluded_project.id])
          end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }

          expect do
            described_class
              .execute(namespace: top_level_group, enable: false, excluded_projects_ids: [excluded_project.id])
          end.to change { security_setting.reload.pre_receive_secret_detection_enabled }
                   .from(true).to(false)

          expect do
            described_class
              .execute(namespace: top_level_group, enable: false, excluded_projects_ids: [excluded_project.id])
          end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
        end
      end

      it 'changes updated_at timestamp' do
        expect { described_class.execute(namespace: top_level_group, enable: true) }
          .to change { mid_level_group_project.reload.security_setting.updated_at }
      end

      it 'doesnt change the attribute for projects in excluded list' do
        security_setting = excluded_project.security_setting
        expect do
          described_class.execute(namespace: top_level_group, enable: true,
            excluded_projects_ids: [excluded_project.id])
        end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }

        expect do
          described_class.execute(namespace: mid_level_group, enable: false,
            excluded_projects_ids: [excluded_project.id])
        end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
      end

      it 'rolls back changes when an error occurs' do
        initial_values = projects_to_change.map do |project|
          project.security_setting.pre_receive_secret_detection_enabled
        end

        call_counter = 0
        # Simulate an error on the last call to `update_security_setting` to make sure some changes were already made
        allow(described_class).to receive(:update_security_setting) do |projects, enable, excluded_projects_ids|
          call_counter += 1
          raise StandardError, "Simulated error on the third project" if call_counter == (projects_to_change.length - 1)

          described_class.send(:super, projects, enable, excluded_projects_ids)
        end

        expect do
          described_class.execute(namespace: top_level_group, enable: true,
            excluded_projects_ids: [excluded_project.id])
        end.to raise_error(StandardError)

        projects_to_change.each_with_index do |project, index|
          project.reload
          expect(project.security_setting.pre_receive_secret_detection_enabled).to eq(initial_values[index])
        end
      end

      context 'when security_setting record does not yet exist' do
        let_it_be_with_reload(:project_without_security_setting) { create(:project, namespace: top_level_group) }

        before do
          project_without_security_setting.security_setting.destroy!
        end

        it 'creates security_setting and sets the value appropriately' do
          expect { described_class.execute(namespace: top_level_group, enable: true) }
            .to change { project_without_security_setting.reload.security_setting }
                  .from(nil).to(be_a(ProjectSecuritySetting))

          expect(project_without_security_setting.reload.security_setting.pre_receive_secret_detection_enabled)
            .to be(true)
        end
      end

      context 'when arguments are invalid' do
        it 'does not change the attribute' do
          expect { described_class.execute(namespace: top_level_group, enable: nil) }
            .not_to change { top_level_group_project.reload.security_setting.pre_receive_secret_detection_enabled }
        end
      end
    end

    context 'when namespace is a project' do
      it 'changes the attribute' do
        security_setting = bottom_level_group_project.security_setting
        expect do
          described_class
            .execute(namespace: bottom_level_group_project, enable: true)
        end.to change { security_setting.reload.pre_receive_secret_detection_enabled }.from(false).to(true)

        expect do
          described_class
            .execute(namespace: bottom_level_group_project, enable: true)
        end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }

        expect do
          described_class
            .execute(namespace: bottom_level_group_project, enable: false)
        end.to change { security_setting.reload.pre_receive_secret_detection_enabled }
                 .from(true).to(false)

        expect do
          described_class
            .execute(namespace: bottom_level_group_project, enable: false)
        end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
      end

      it 'changes updated_at timestamp' do
        expect { described_class.execute(namespace: mid_level_group_project, enable: true) }
          .to change { mid_level_group_project.reload.security_setting.updated_at }
      end

      it 'doesnt change the attribute for a project when it is in the excluded list' do
        security_setting = excluded_project.security_setting
        expect do
          described_class.execute(namespace: excluded_project,
            enable: !security_setting.pre_receive_secret_detection_enabled,
            excluded_projects_ids: [excluded_project.id])
        end.not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
      end

      context 'when security_setting record does not yet exist' do
        let_it_be_with_reload(:project_without_security_setting) { create(:project, namespace: top_level_group) }

        before do
          project_without_security_setting.security_setting.destroy!
        end

        it 'creates security_setting and sets the value appropriately' do
          expect { described_class.execute(namespace: project_without_security_setting, enable: true) }
            .to change { project_without_security_setting.reload.security_setting }
                  .from(nil).to(be_a(ProjectSecuritySetting))

          expect(project_without_security_setting.reload.security_setting.pre_receive_secret_detection_enabled)
            .to be(true)
        end
      end

      context 'when arguments are invalid' do
        it 'does not change the attribute' do
          expect { described_class.execute(namespace: bottom_level_group_project, enable: nil) }
            .not_to change { bottom_level_group_project.reload.security_setting.pre_receive_secret_detection_enabled }
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRolesHelper, feature_category: :permissions do
  include ApplicationHelper

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:source) { build_stubbed(:group) }
  let_it_be(:root_group) { source.root_ancestor }

  before do
    stub_licensed_features(custom_roles: true)
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#member_roles_data' do
    let(:expected_data) do
      {
        documentation_path: help_page_path('user/custom_roles'),
        empty_state_svg_path: start_with('/assets/illustrations/empty-state/empty-user-settings-md')
      }
    end

    context 'when on self-managed' do
      subject(:data) { helper.member_roles_data }

      context 'for admin user', :enable_admin_mode do
        let_it_be(:user) { build_stubbed(:admin) }

        context 'when custom roles are available' do
          it 'matches the expected data' do
            expect(data).to match(hash_including(expected_data))
            expect(data[:new_role_path]).to eq new_admin_application_settings_roles_and_permission_path
            expect(data[:group_full_path]).to eq nil
          end
        end

        context 'when custom roles are not available' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'matches the expected data' do
            expect(data).to match(hash_including(expected_data))
            expect(data[:new_role_path]).to be_nil
            expect(data[:group_full_path]).to eq nil
          end
        end
      end

      context 'for non-admin user' do
        it 'matches the expected data' do
          expect(data).to match(hash_including(expected_data))
          expect(data[:new_role_path]).to be_nil
          expect(data[:group_full_path]).to eq nil
        end
      end
    end

    context 'when on SaaS', :saas do
      context 'when on group page' do
        subject(:data) { helper.member_roles_data(source) }

        shared_examples 'custom roles are not available' do
          it 'matches the expected data' do
            expect(data).to match(hash_including(expected_data))
            expect(data[:new_role_path]).to be_nil
            expect(data[:group_full_path]).to eq source.full_path
          end
        end

        context 'as group owner' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_group_member, root_group).and_return(true)
          end

          context 'when custom roles are available' do
            it 'matches the expected data' do
              expect(data).to match(hash_including(expected_data))
              expect(data[:new_role_path]).to eq new_group_settings_roles_and_permission_path(source)
              expect(data[:group_full_path]).to eq source.full_path
            end
          end

          context 'when custom roles are not available' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            it_behaves_like 'custom roles are not available'
          end
        end

        context 'as group non-owner' do
          it_behaves_like 'custom roles are not available'
        end
      end
    end
  end

  describe '#manage_member_roles_path' do
    subject { helper.manage_member_roles_path(source) }

    context 'when on SaaS', :saas do
      it { is_expected.to be_nil }

      context 'as owner' do
        before do
          allow(helper).to receive(:can?).with(user, :admin_group_member, root_group).and_return(true)
        end

        it { is_expected.to eq(group_settings_roles_and_permissions_path(root_group)) }

        context 'when custom roles are not available' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end

    context 'when in admin mode', :enable_admin_mode do
      it { is_expected.to be_nil }

      context 'as admin' do
        let_it_be(:user) { build_stubbed(:user, :admin) }

        it { is_expected.to eq(admin_application_settings_roles_and_permissions_path) }

        context 'when custom roles are not available' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#member_role_edit_path' do
    context 'when on self-managed' do
      subject { helper.member_role_edit_path(role) }

      let_it_be(:role) { build_stubbed(:member_role, id: 5) }

      it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
    end

    context 'when on Saas', :saas do
      subject { helper.member_role_edit_path(role) }

      let_it_be(:role) { build_stubbed(:member_role, id: 5, namespace: source) }

      it { is_expected.to eq(edit_group_settings_roles_and_permission_path(source, role)) }
    end
  end

  describe '#member_role_details_path' do
    subject { helper.member_role_details_path(role) }

    let_it_be(:role) { build_stubbed(:member_role, id: 5, namespace: root_group) }

    context 'when on self-managed' do
      it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
    end

    context 'when on Saas', :saas do
      it { is_expected.to eq(group_settings_roles_and_permission_path(root_group, role)) }
    end
  end
end

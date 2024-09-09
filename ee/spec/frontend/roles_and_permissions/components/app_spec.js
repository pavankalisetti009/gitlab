import { GlLoadingIcon, GlButton, GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import groupMemberRolesQuery from 'ee/roles_and_permissions/graphql/group_member_roles.query.graphql';
import instanceMemberRolesQuery from 'ee/roles_and_permissions/graphql/instance_member_roles.query.graphql';

import RolesApp from 'ee/roles_and_permissions/components/app.vue';
import CustomRolesEmptyState from 'ee/roles_and_permissions/components/custom_roles_empty_state.vue';
import RolesTable from 'ee/roles_and_permissions/components/roles_table.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';

import { mockEmptyMemberRoles, mockMemberRoles, mockInstanceMemberRoles } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Roles app', () => {
  let wrapper;

  const mockCustomRoleToDelete = mockMemberRoles.data.namespace.memberRoles.nodes[0];

  const mockToastShow = jest.fn();
  const groupRolesSuccessQueryHandler = jest.fn().mockResolvedValue(mockMemberRoles);
  const instanceRolesSuccessQueryHandler = jest.fn().mockResolvedValue(mockInstanceMemberRoles);

  const errorHandler = jest.fn().mockRejectedValue('error');

  const createComponent = ({
    groupRolesQueryHandler = groupRolesSuccessQueryHandler,
    instanceRolesQueryHandler = instanceRolesSuccessQueryHandler,
    groupFullPath = 'test-group',
  } = {}) => {
    wrapper = shallowMountExtended(RolesApp, {
      apolloProvider: createMockApollo([
        [groupMemberRolesQuery, groupRolesQueryHandler],
        [instanceMemberRolesQuery, instanceRolesQueryHandler],
      ]),
      provide: {
        groupFullPath,
        documentationPath: 'http://foo.bar',
        newRolePath: 'new/role/path',
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });

    return waitForPromises();
  };

  const findEmptyState = () => wrapper.findComponent(CustomRolesEmptyState);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTable = () => wrapper.findComponent(RolesTable);
  const findHeader = () => wrapper.find('header');
  const findCount = () => wrapper.findByTestId('custom-roles-count');
  const findButton = () => wrapper.findComponent(GlButton);
  const findDeleteModal = () => wrapper.findComponent(DeleteRoleModal);

  describe('on creation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when data has loaded', () => {
    describe('and there are no custom roles', () => {
      beforeEach(() =>
        createComponent({
          groupRolesQueryHandler: jest.fn().mockResolvedValue(mockEmptyMemberRoles),
        }),
      );

      it('renders the empty state', () => {
        expect(findEmptyState().exists()).toBe(true);
      });
    });

    describe('and there group-level custom roles', () => {
      beforeEach(createComponent);

      it('fetches group-level member roles', () => {
        expect(groupRolesSuccessQueryHandler).toHaveBeenCalledWith({
          fullPath: 'test-group',
        });
      });

      it('renders the title', () => {
        expect(findHeader().text()).toContain('Custom roles');
      });

      it('renders the new role button', () => {
        expect(findButton().text()).toContain('New role');
        expect(findButton().attributes('href')).toBe('new/role/path');
      });

      it('renders the number of roles', () => {
        expect(findCount().text()).toBe('2 Custom roles');
      });

      it('renders the table', () => {
        expect(findTable().exists()).toBe(true);

        expect(findTable().props('roles')).toEqual(
          mockMemberRoles.data.namespace.memberRoles.nodes,
        );
      });
    });

    describe('and there instance-level custom roles', () => {
      beforeEach(() => createComponent({ groupFullPath: null }));

      it('fetches instance-level member roles', () => {
        expect(instanceRolesSuccessQueryHandler).toHaveBeenCalledWith({});
      });

      it('renders the table', () => {
        expect(findTable().exists()).toBe(true);

        expect(findTable().props('roles')).toEqual(mockInstanceMemberRoles.data.memberRoles.nodes);
      });
    });

    describe('and there is an error fetching the data', () => {
      beforeEach(() => createComponent({ groupRolesQueryHandler: errorHandler }));

      it('renders the error message', () => {
        const alert = wrapper.findComponent(GlAlert);

        expect(alert.text()).toBe('Failed to fetch roles.');
        expect(alert.props()).toMatchObject({
          variant: 'danger',
          dismissible: false,
        });
      });

      it('does not render empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not render table', () => {
        expect(findTable().exists()).toBe(false);
      });
    });
  });

  describe('delete role modal', () => {
    beforeEach(createComponent);

    it('renders delete modal', () => {
      expect(findDeleteModal().exists()).toBe(true);
    });

    describe('when table wants to delete a role', () => {
      beforeEach(() => {
        findTable().vm.$emit('delete-role', mockCustomRoleToDelete);
      });

      it('passes role to delete modal', () => {
        expect(findDeleteModal().props('role')).toBe(mockCustomRoleToDelete);
      });

      it('closes modal when modal emits close event', async () => {
        findDeleteModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteModal().props('role')).toBe(null);
      });
    });

    describe('when modal finishes deleting a role', () => {
      beforeEach(() => {
        findDeleteModal().vm.$emit('deleted');
      });

      it('shows toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith('Role successfully deleted.');
      });

      it('closes modal', () => {
        expect(findDeleteModal().props('role')).toBe(null);
      });

      it('refetches custom roles query', () => {
        expect(groupRolesSuccessQueryHandler).toHaveBeenCalledTimes(2);
      });
    });
  });
});

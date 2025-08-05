import { GlButton, GlSprintf, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupRolesQuery from 'ee/roles_and_permissions/graphql/group_roles.query.graphql';
import instanceRolesQuery from 'ee/roles_and_permissions/graphql/instance_roles.query.graphql';
import adminRolesQuery from 'ee/roles_and_permissions/graphql/admin_roles.query.graphql';
import RolesCrud from 'ee/roles_and_permissions/components/roles_crud/roles_crud.vue';
import RolesTable from 'ee/roles_and_permissions/components/roles_table/roles_table.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import RolesExport from 'ee/roles_and_permissions/components/roles_table/roles_export.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { createAlert } from '~/alert';
import {
  standardRoles,
  memberRoles,
  adminRoles,
  groupRolesResponse,
  instanceRolesResponse,
  saasAdminRolesResponse,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('RolesCrud component', () => {
  let wrapper;

  const mockToastShow = jest.fn();
  const groupRolesSuccessQueryHandler = jest.fn().mockResolvedValue(groupRolesResponse);
  const instanceRolesSuccessQueryHandler = jest.fn().mockResolvedValue(instanceRolesResponse);
  const saasAdminRolesSuccessQueryHandler = jest.fn().mockResolvedValue(saasAdminRolesResponse);

  const createComponent = ({
    groupRolesQueryHandler = groupRolesSuccessQueryHandler,
    instanceRolesQueryHandler = instanceRolesSuccessQueryHandler,
    adminRolesQueryHandler = saasAdminRolesSuccessQueryHandler,
    groupFullPath = 'test-group',
    newRolePath = 'new/role/path',
    isSaas = false,
    membersPermissionsDetailedExport = true,
    exportGroupMemberships = true,
    customRoles = true,
    customAdminRoles = true,
  } = {}) => {
    wrapper = shallowMountExtended(RolesCrud, {
      apolloProvider: createMockApollo([
        [groupRolesQuery, groupRolesQueryHandler],
        [instanceRolesQuery, instanceRolesQueryHandler],
        [adminRolesQuery, adminRolesQueryHandler],
      ]),
      provide: {
        groupFullPath,
        newRolePath,
        isSaas,
        glFeatures: { membersPermissionsDetailedExport, customRoles, customAdminRoles },
        glAbilities: { exportGroupMemberships },
      },
      stubs: {
        GlSprintf,
        PageHeading,
        CrudComponent,
        GlDisclosureDropdown,
        GlDisclosureDropdownItem,
      },
      mocks: { $toast: { show: mockToastShow } },
    });

    return waitForPromises();
  };

  const findRolesTable = () => wrapper.findComponent(RolesTable);
  const findRoleCounts = () => wrapper.findByTestId('role-counts');
  const findDeleteModal = () => wrapper.findComponent(DeleteRoleModal);
  const findRolesExport = () => wrapper.findComponent(RolesExport);
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findNewRoleButton = () => wrapper.findComponent(GlButton);

  describe('common behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the New role button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.text()).toBe('New role');
      expect(button.props('size')).toBe('small');
      expect(button.attributes('href')).toBe('new/role/path');
    });

    describe('roles table busy state', () => {
      it('shows table as busy on page load', () => {
        expect(findRolesTable().props('busy')).toBe(true);
      });

      it('shows table as not busy after roles data is loaded', async () => {
        await waitForPromises();

        expect(findRolesTable().props('busy')).toBe(false);
      });
    });
  });

  describe('new role button', () => {
    it('shows split dropdown button when admin roles can be created', () => {
      createComponent({ groupFullPath: '' });

      expect(findDisclosureDropdown().props()).toMatchObject({
        toggleText: 'New role',
        placement: 'bottom-end',
        fluidWidth: true,
        items: [
          {
            text: 'Member role',
            href: 'new/role/path',
            description: 'Create a role to manage member permissions for groups and projects.',
          },
          {
            text: 'Admin role',
            href: 'new/role/path?admin',
            description: 'Create a role to manage permissions in the Admin area.',
          },
        ],
      });
    });

    it.each`
      phrase                                  | options
      ${'for groups'}                         | ${{ groupFullPath: 'group' }}
      ${'when admin roles cannot be created'} | ${{ customAdminRoles: false }}
    `('shows new role button $phrase', ({ options }) => {
      createComponent(options);

      expect(findDisclosureDropdown().exists()).toBe(false);
      expect(findNewRoleButton().text()).toBe('New role');
      expect(findNewRoleButton().attributes('href')).toBe('new/role/path');
    });
  });

  describe.each`
    type            | isSaas   | groupFullPath   | queryHandler                         | expectedQueryData
    ${'SaaS group'} | ${true}  | ${'test-group'} | ${groupRolesSuccessQueryHandler}     | ${{ fullPath: 'test-group', includeCustomRoles: true, includeAdminRoles: true }}
    ${'SaaS admin'} | ${true}  | ${''}           | ${saasAdminRolesSuccessQueryHandler} | ${{ fullPath: '', includeCustomRoles: true, includeAdminRoles: true }}
    ${'instance'}   | ${false} | ${''}           | ${instanceRolesSuccessQueryHandler}  | ${{ fullPath: '', includeCustomRoles: true, includeAdminRoles: true }}
  `('for $type-level roles', ({ isSaas, groupFullPath, queryHandler, expectedQueryData }) => {
    beforeEach(() => createComponent({ isSaas, groupFullPath }));

    it('fetches roles', () => {
      expect(queryHandler).toHaveBeenCalledWith(expectedQueryData);
    });
  });

  describe('for Self-Managed roles', () => {
    beforeEach(() => createComponent({ groupFullPath: '', isSaas: false }));

    it('fetches instance roles', () => {
      expect(instanceRolesSuccessQueryHandler).toHaveBeenCalledWith({
        fullPath: '',
        includeCustomRoles: true,
        includeAdminRoles: true,
      });
    });

    it('shows role counts with admin roles', () => {
      expect(findRoleCounts().text()).toBe('6 Default 2 Custom 2 Admin');
    });

    it('passes admin roles to roles table', () => {
      expect(findRolesTable().props('roles')).toEqual(expect.arrayContaining(adminRoles));
    });
  });

  describe('for SaaS instance-level roles', () => {
    beforeEach(() => createComponent({ groupFullPath: '', isSaas: true }));

    it('shows role counts with admin roles', () => {
      expect(findRoleCounts().text()).toBe('0 Default 0 Custom 2 Admin');
    });

    it('passes admin roles to roles table', () => {
      expect(findRolesTable().props('roles')).toEqual(expect.arrayContaining(adminRoles));
    });
  });

  describe('when there is a query error', () => {
    it('shows an error message for group roles', async () => {
      await createComponent({
        isSaas: true,
        groupRolesQueryHandler: jest.fn().mockRejectedValue(),
      });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch roles.',
        dismissible: false,
      });
    });

    it('shows an error message for SaaS admin roles', async () => {
      await createComponent({
        groupFullPath: '',
        isSaas: true,
        adminRolesQueryHandler: jest.fn().mockRejectedValue(),
      });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch roles.',
        dismissible: false,
      });
    });
  });

  describe('delete role modal', () => {
    beforeEach(() => createComponent());

    it('renders modal', () => {
      expect(findDeleteModal().exists()).toBe(true);
    });

    describe('when table wants to delete a role', () => {
      beforeEach(() => {
        findRolesTable().vm.$emit('delete-role', memberRoles[0]);
      });

      it('passes role to delete modal', () => {
        expect(findDeleteModal().props('role')).toBe(memberRoles[0]);
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
        expect(instanceRolesSuccessQueryHandler).toHaveBeenCalledTimes(2);
      });
    });
  });

  describe('when newRolePath is not set', () => {
    beforeEach(() => {
      createComponent({ newRolePath: null });
    });

    it('does not show the New role button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.exists()).toBe(false);
    });
  });

  describe('roles export', () => {
    it('does not show roles export when user does not have the ability to export', () => {
      createComponent({ exportGroupMemberships: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('does not show roles export when membersPermissionsDetailedExport feature flag is off', () => {
      createComponent({ membersPermissionsDetailedExport: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('shows roles export when user has ability to export', () => {
      createComponent({ exportGroupMemberships: true });

      expect(findRolesExport().exists()).toBe(true);
    });
  });

  describe('when member roles is null', () => {
    beforeEach(() =>
      createComponent({
        isSaas: true,
        groupRolesQueryHandler: jest.fn().mockResolvedValue({
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              standardRoles: { nodes: standardRoles },
              memberRoles: null,
            },
          },
        }),
      }),
    );

    it('renders the standard roles', () => {
      expect(findRolesTable().props('roles')).toHaveLength(standardRoles.length);
    });
  });
});

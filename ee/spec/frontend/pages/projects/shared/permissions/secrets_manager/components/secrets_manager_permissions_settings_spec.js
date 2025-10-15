import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getSecretsPermissionsQuery from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/secrets_permission.query.graphql';
import deleteSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/delete_secrets_permission.mutation.graphql';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';
import {
  mockDeletePermissionResponse,
  mockPermissionsQueryResponse,
  OWNER_PERMISSION_NODE,
  ROLE_PERMISSION_NODE,
  GROUP_PERMISSION_NODE,
  USER_PERMISSION_NODE,
} from '../mock_data';

jest.mock('~/alert');
const mockToastShow = jest.fn();
Vue.use(VueApollo);

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;
  let mockApollo;
  let mockPermissionsQuery;
  let mockDeletePermissionMutation;

  const createComponent = async ({ canManageSecretsManager = true } = {}) => {
    mockApollo = createMockApollo([
      [getSecretsPermissionsQuery, mockPermissionsQuery],
      [deleteSecretsPermissionMutation, mockDeletePermissionMutation],
    ]);

    wrapper = shallowMountExtended(PermissionsSettings, {
      apolloProvider: mockApollo,
      provide: {
        fullPath: '/path/to/project',
      },
      propsData: {
        canManageSecretsManager,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });

    await waitForPromises();
  };

  const findActionsDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPermissionsTable = (index) => wrapper.findAllComponents(PermissionsTable).at(index);
  const findPermissionsTables = () => wrapper.findAllComponents(PermissionsTable);
  const findCreatePermissionModal = () => wrapper.findComponent(PermissionsModal);
  const findDeletePermissionModal = () => wrapper.findByTestId('delete-permission-modal');

  const deletePermission = async () => {
    findDeletePermissionModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockPermissionsQuery = jest.fn().mockResolvedValue(mockPermissionsQueryResponse());
    mockDeletePermissionMutation = jest.fn().mockResolvedValue(mockDeletePermissionResponse());
  });

  describe('while permissions query is loading', () => {
    it('renders loading icon and does not render tabs', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findPermissionsTables()).toHaveLength(0);
    });
  });

  describe('when permissions query is successful', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders user table', () => {
      expect(findPermissionsTable(0).props('permissionCategory')).toBe('USER');
      expect(findPermissionsTable(0).props('items')).toStrictEqual([USER_PERMISSION_NODE]);
    });

    it('renders group table', () => {
      expect(findPermissionsTable(1).props('permissionCategory')).toBe('GROUP');
      expect(findPermissionsTable(1).props('items')).toStrictEqual([GROUP_PERMISSION_NODE]);
    });

    it('renders role table', () => {
      expect(findPermissionsTable(2).props('permissionCategory')).toBe('ROLE');
      expect(findPermissionsTable(2).props('items')).toStrictEqual([
        OWNER_PERMISSION_NODE,
        ROLE_PERMISSION_NODE,
      ]);
    });
  });

  describe('when permissions query fails', () => {
    const returnedError = new Error();
    beforeEach(async () => {
      mockPermissionsQuery = jest.fn().mockRejectedValue(returnedError);

      await createComponent();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch secrets manager permissions. Please try again later.',
        captureError: true,
        error: returnedError,
      });
    });
  });

  describe('canManageSecretsManager permission', () => {
    it('renders actions dropdown and delete button and when user has permission', async () => {
      await createComponent();

      expect(findActionsDropdown().exists()).toBe(true);
      expect(findPermissionsTable(0).props('canDelete')).toBe(true);
      expect(findPermissionsTable(1).props('canDelete')).toBe(true);
      expect(findPermissionsTable(2).props('canDelete')).toBe(true);
    });

    it("does not render actions dropdown and delete button when user doesn't have permission", async () => {
      await createComponent({ canManageSecretsManager: false });

      expect(findActionsDropdown().exists()).toBe(false);
      expect(findPermissionsTable(0).props('canDelete')).toBe(false);
      expect(findPermissionsTable(1).props('canDelete')).toBe(false);
      expect(findPermissionsTable(2).props('canDelete')).toBe(false);
    });
  });

  describe('create permissions modal', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('passes the correct selected permission category', async () => {
      expect(findCreatePermissionModal().props('permissionCategory')).toBe(null);

      findActionsDropdown().vm.$emit('select', 'USER');
      await nextTick();

      expect(findCreatePermissionModal().props('permissionCategory')).toBe('USER');

      findActionsDropdown().vm.$emit('select', 'ROLE');
      await nextTick();

      expect(findCreatePermissionModal().props('permissionCategory')).toBe('ROLE');
    });

    it('resets permission category when modal is hidden', async () => {
      findActionsDropdown().vm.$emit('select', 'GROUP');
      await nextTick();

      expect(findCreatePermissionModal().props('permissionCategory')).toBe('GROUP');

      findCreatePermissionModal().vm.$emit('hide');
      await nextTick();

      expect(findCreatePermissionModal().props('permissionCategory')).toBe(null);
    });

    it('refetches permissions when refetch event is emitted', async () => {
      expect(mockPermissionsQuery).toHaveBeenCalledTimes(1);

      findCreatePermissionModal().vm.$emit('refetch');
      await waitForPromises();

      expect(mockPermissionsQuery).toHaveBeenCalledTimes(2);
    });
  });

  describe('delete permissions modal', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('hides delete permission modal by default', () => {
      expect(findDeletePermissionModal().props('visible')).toBe(false);
    });

    const userPrincipal = {
      id: 49,
      type: 'USER',
      group: null,
      user: {
        name: 'Ginny McGlynn',
      },
    };

    const groupPrincipal = {
      id: 22,
      type: 'GROUP',
      group: {
        name: 'Toolbox',
      },
      user: null,
    };

    const rolePrincipal = {
      id: 30,
      type: 'ROLE',
      group: null,
      user: null,
    };

    describe.each`
      permissionCategory | principal         | modalDescription   | principalParams
      ${'User'}          | ${userPrincipal}  | ${'Ginny McGlynn'} | ${{ id: 49, type: 'USER' }}
      ${'Group'}         | ${groupPrincipal} | ${'Toolbox'}       | ${{ id: 22, type: 'GROUP' }}
      ${'Role'}          | ${rolePrincipal}  | ${'Developer'}     | ${{ id: 30, type: 'ROLE' }}
    `(
      'when deleting a $permissionCategory permission',
      ({ principal, modalDescription, principalParams }) => {
        beforeEach(() => {
          findPermissionsTable(0).vm.$emit('delete-permission', principal);
          return nextTick();
        });

        it('shows correct details in the delete modal', () => {
          expect(findDeletePermissionModal().props('visible')).toBe(true);
          expect(findDeletePermissionModal().text()).toContain(modalDescription);
        });

        it('calls the delete mutation with the correct variables', async () => {
          await deletePermission();

          expect(mockDeletePermissionMutation).toHaveBeenCalledWith({
            projectPath: '/path/to/project',
            principal: { ...principalParams },
          });
        });

        it('refetches permissions', async () => {
          expect(mockPermissionsQuery).toHaveBeenCalledTimes(1);

          await deletePermission();

          expect(mockPermissionsQuery).toHaveBeenCalledTimes(2);
        });

        it('hides modal and shows toast message on successful submission', async () => {
          await deletePermission();

          expect(findDeletePermissionModal().props('visible')).toBe(false);
          expect(mockToastShow).toHaveBeenCalledWith('Permissions for secrets manager removed.');
        });
      },
    );

    describe('when deletion returns errors', () => {
      beforeEach(() => {
        mockDeletePermissionMutation = jest
          .fn()
          .mockResolvedValue(mockDeletePermissionResponse('Missing parameters.'));
        return createComponent();
      });

      it('renders error message from API', async () => {
        findPermissionsTable(0).vm.$emit('delete-permission', rolePrincipal);
        await nextTick();
        await deletePermission();

        expect(createAlert).toHaveBeenCalledWith({ message: 'Missing parameters.' });
      });
    });

    describe('when deletion fails', () => {
      const error = new Error();

      beforeEach(() => {
        mockDeletePermissionMutation.mockRejectedValue(error);
        return createComponent();
      });

      it('renders error message', async () => {
        findPermissionsTable(0).vm.$emit('delete-permission', rolePrincipal);
        await nextTick();
        await deletePermission();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to delete secrets manager permissions. Please try again.',
          captureError: true,
          error,
        });
      });
    });
  });
});

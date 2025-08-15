import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getSecretsPermissionsQuery from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/secrets_permission.query.graphql';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';
import {
  mockPermissionsQueryResponse,
  OWNER_PERMISSION_NODE,
  ROLE_PERMISSION_NODE,
  GROUP_PERMISSION_NODE,
  USER_PERMISSION_NODE,
} from '../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;
  let mockApollo;
  let mockPermissionsQuery;

  const createComponent = async ({ canManageSecretsManager = true } = {}) => {
    mockApollo = createMockApollo([[getSecretsPermissionsQuery, mockPermissionsQuery]]);

    wrapper = shallowMountExtended(PermissionsSettings, {
      apolloProvider: mockApollo,
      provide: {
        fullPath: '/path/to/project',
      },
      propsData: {
        canManageSecretsManager,
      },
    });

    await waitForPromises();
  };

  const findActionsDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPermissionsTable = (index) => wrapper.findAllComponents(PermissionsTable).at(index);
  const findPermissionsTables = () => wrapper.findAllComponents(PermissionsTable);
  const findModal = () => wrapper.findComponent(PermissionsModal);

  beforeEach(() => {
    mockPermissionsQuery = jest.fn().mockResolvedValue(mockPermissionsQueryResponse());
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

  describe('actions dropdown', () => {
    it('renders actions dropdown when user has permissions', async () => {
      await createComponent();

      expect(findActionsDropdown().exists()).toBe(true);
    });

    it("does not render actions dropdown when user doesn't have permission", async () => {
      await createComponent({ canManageSecretsManager: false });

      expect(findActionsDropdown().exists()).toBe(false);
    });
  });

  describe('permissions modal', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('passes the correct selected permission category', async () => {
      expect(findModal().props('permissionCategory')).toBe(null);

      findActionsDropdown().vm.$emit('select', 'USER');
      await nextTick();

      expect(findModal().props('permissionCategory')).toBe('USER');

      findActionsDropdown().vm.$emit('select', 'ROLE');
      await nextTick();

      expect(findModal().props('permissionCategory')).toBe('ROLE');
    });

    it('resets permission category when modal is hidden', async () => {
      findActionsDropdown().vm.$emit('select', 'GROUP');
      await nextTick();

      expect(findModal().props('permissionCategory')).toBe('GROUP');

      findModal().vm.$emit('hide');
      await nextTick();

      expect(findModal().props('permissionCategory')).toBe(null);
    });

    it('refetches permissions when refetch event is emitted', async () => {
      expect(mockPermissionsQuery).toHaveBeenCalledTimes(1);

      findModal().vm.$emit('refetch');
      await waitForPromises();

      expect(mockPermissionsQuery).toHaveBeenCalledTimes(2);
    });
  });
});

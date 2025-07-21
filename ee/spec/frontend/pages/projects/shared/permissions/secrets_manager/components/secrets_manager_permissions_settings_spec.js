import { nextTick } from 'vue';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;

  const createComponent = ({ props, canManageSecretsManager = true } = {}) => {
    wrapper = shallowMountExtended(PermissionsSettings, {
      propsData: {
        canManageSecretsManager,
        fullPath: '/path/to/project',
        ...props,
      },
    });
  };

  const findActionsDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPermissionsTable = (index) => wrapper.findAllComponents(PermissionsTable).at(index);
  const findModal = () => wrapper.findComponent(PermissionsModal);

  describe('template', () => {
    it('renders permissions tables', () => {
      createComponent();

      expect(findPermissionsTable(0).props('permissionCategory')).toBe('USER');
      expect(findPermissionsTable(1).props('permissionCategory')).toBe('GROUP');
      expect(findPermissionsTable(2).props('permissionCategory')).toBe('ROLE');
    });

    it('renders actions dropdown when user has permissions', () => {
      createComponent();

      expect(findActionsDropdown().exists()).toBe(true);
    });

    it("does not render actions dropdown when user doesn't have permission", () => {
      createComponent({ canManageSecretsManager: false });

      expect(findActionsDropdown().exists()).toBe(false);
    });
  });

  describe('permissions modal', () => {
    beforeEach(() => {
      createComponent();
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
  });
});

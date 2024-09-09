import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RoleActions from 'ee/roles_and_permissions/components/role_actions.vue';

describe('Role actions', () => {
  let wrapper;

  const mockCustomRole = { membersCount: 0, editPath: 'edit/path' };

  const createComponent = ({ role = mockCustomRole } = {}) => {
    wrapper = mountExtended(RoleActions, {
      propsData: { role },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItem = (index) =>
    findDropdown().findAllComponents(GlDisclosureDropdownItem).at(index);

  const findEditRole = () => findDropdownItem(0);
  const findDeleteRole = () => findDropdownItem(1);

  beforeEach(() => {
    createComponent();
  });

  it('renders the actions dropdown', () => {
    expect(findDropdown().exists()).toBe(true);

    expect(findDropdown().props()).toMatchObject({
      icon: 'ellipsis_v',
      category: 'tertiary',
      placement: 'bottom-end',
    });
  });

  describe('edit role', () => {
    it('renders the edit role action item', () => {
      expect(findEditRole().props('item')).toMatchObject({ text: 'Edit role', href: 'edit/path' });
    });
  });

  describe('delete role', () => {
    it('renders the delete role action item', () => {
      expect(findDeleteRole().props('item')).toMatchObject({
        text: 'Delete role',
        extraAttrs: { class: '!gl-text-red-500' },
      });
    });

    it('emits `delete` event when delete role is clicked', async () => {
      await findDeleteRole().find('button').trigger('click');

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    describe('when `membersCount` of a custom role is greater than 0', () => {
      beforeEach(() => {
        createComponent({ role: { membersCount: 1 } });
      });

      it('disables the delete role action item', () => {
        expect(findDeleteRole().props('item').extraAttrs.disabled).toBe(true);
      });
    });
  });
});

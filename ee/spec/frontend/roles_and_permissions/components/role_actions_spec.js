import { GlDisclosureDropdown, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RoleActions from 'ee/roles_and_permissions/components/role_actions.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

describe('Role actions', () => {
  let wrapper;

  const mockToastShow = jest.fn();
  const defaultRole = { accessLevel: 10 };
  const customRole = {
    id: 1,
    membersCount: 0,
    detailsPath: 'role/path/1',
    editPath: 'role/path/1/edit',
  };
  const customRoleWithMembers = {
    id: 2,
    membersCount: 2,
    detailsPath: 'role/path/2',
    editPath: 'role/path/2/edit',
  };

  const createComponent = ({ role = customRole } = {}) => {
    wrapper = mountExtended(RoleActions, {
      propsData: { role },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      mocks: { $toast: { show: mockToastShow } },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findRoleIdItem = () => wrapper.findByTestId('role-id-item');
  const findViewDetailsItem = () => wrapper.findByTestId('view-details-item');
  const findEditRoleItem = () => wrapper.findByTestId('edit-role-item');
  const findDeleteRoleItem = () => wrapper.findByTestId('delete-role-item');
  const findDeleteRoleItemTooltip = () => getBinding(findDeleteRoleItem().element, 'gl-tooltip');

  describe('common behavior', () => {
    beforeEach(() => createComponent());

    it('renders the actions dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        icon: 'ellipsis_v',
        category: 'tertiary',
        noCaret: true,
      });
    });

    it('shows View details item', () => {
      expect(findViewDetailsItem().props('item')).toMatchObject({
        text: 'View details',
        href: 'role/path/1',
      });
    });
  });

  describe.each`
    type         | role           | id      | expectedText          | expectedToast
    ${'default'} | ${defaultRole} | ${'10'} | ${'Access level: 10'} | ${'Access level copied to clipboard'}
    ${'custom'}  | ${customRole}  | ${'1'}  | ${'Role ID: 1'}       | ${'Role ID copied to clipboard'}
  `('role ID item for $type role', ({ role, id, expectedText, expectedToast }) => {
    beforeEach(() => createComponent({ role }));

    it('shows clipboard icon', () => {
      expect(findRoleIdItem().findComponent(GlIcon).props('name')).toBe('copy-to-clipboard');
    });

    it('shows role ID', () => {
      expect(findRoleIdItem().attributes('data-clipboard-text')).toBe(id);
      expect(findRoleIdItem().text()).toBe(expectedText);
    });

    it('shows copied to clipboard toast when clicked', async () => {
      findRoleIdItem().vm.$emit('action');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith(expectedToast);
    });
  });

  describe('for default role', () => {
    beforeEach(() => createComponent({ role: defaultRole }));

    it('does not show Edit role item', () => {
      expect(findEditRoleItem().exists()).toBe(false);
    });

    it('does not show Delete role item', () => {
      expect(findDeleteRoleItem().exists()).toBe(false);
    });
  });

  describe('for custom role', () => {
    beforeEach(() => createComponent({ role: customRole }));

    it('shows Edit role item', () => {
      expect(findEditRoleItem().props('item')).toMatchObject({
        text: 'Edit role',
        href: 'role/path/1/edit',
      });
    });

    describe('Delete role item', () => {
      it('shows item', () => {
        expect(findDeleteRoleItem().props('item')).toMatchObject({
          text: 'Delete role',
          extraAttrs: { disabled: false, class: '!gl-text-red-500' },
        });
      });

      it('does not have tooltip text', () => {
        expect(findDeleteRoleItemTooltip()).toMatchObject({ value: '' });
      });

      it('emits delete event when clicked', async () => {
        await findDeleteRoleItem().find('button').trigger('click');

        expect(wrapper.emitted('delete')).toHaveLength(1);
      });
    });
  });

  describe('Delete role item when there are members assigned to role', () => {
    beforeEach(() => createComponent({ role: customRoleWithMembers }));

    it('shows item', () => {
      expect(findDeleteRoleItem().props('item')).toMatchObject({
        extraAttrs: { disabled: true, class: '' },
      });
    });

    it('has expected tooltip', () => {
      const tooltip = getBinding(findDeleteRoleItem().element, 'gl-tooltip');

      expect(tooltip).toEqual({
        value: 'To delete custom role, remove role from all group members.',
        modifiers: { d0: true, left: true, viewport: true },
      });
    });
  });
});

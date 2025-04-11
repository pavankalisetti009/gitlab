import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlListboxItem, GlAlert, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AdminRoleDropdown from 'ee/admin/users/components/user_type/admin_role_dropdown.vue';
import adminRolesQuery from 'ee/admin/users/graphql/admin_roles.query.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { adminRoles } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/utils/url_utility');

describe('AdminRoleDropdown component', () => {
  let wrapper;

  const getAdminRolesHandler = (roles = []) =>
    jest.fn().mockResolvedValue({ data: { adminMemberRoles: { nodes: roles } } });
  const defaultAdminRolesHandler = getAdminRolesHandler(adminRoles);

  const createWrapper = ({ adminRolesHandler = defaultAdminRolesHandler, roleId = 1 } = {}) => {
    wrapper = mountExtended(AdminRoleDropdown, {
      apolloProvider: createMockApollo([[adminRolesQuery, adminRolesHandler]]),
      provide: { manageRolesPath: 'manage/roles/path' },
      propsData: { roleId },
    });

    return waitForPromises();
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItemAt = (index) => wrapper.findAllComponents(GlListboxItem).at(index);
  const findPermissionAt = (index) => wrapper.findByTestId('permissions').findAll('li').at(index);
  const getHiddenInputValue = () => wrapper.find('input[type="hidden"]').element.value;
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('on page load', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows header text', () => {
      expect(findDropdown().props('headerText')).toBe('Change access');
    });

    it('shows reset button label', () => {
      expect(findDropdown().props('resetButtonLabel')).toBe('Manage roles');
    });

    it('sets dropdown as loading', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('shows loading message in dropdown button', () => {
      expect(findDropdown().props('toggleText')).toBe('Loading...');
    });

    it('runs admin roles query', () => {
      expect(defaultAdminRolesHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('after roles are loaded', () => {
    beforeEach(() => createWrapper());

    it('shows roles in dropdown', () => {
      const roles = adminRoles.map((role) => ({
        ...role,
        value: getIdFromGraphQLId(role.id),
        text: role.name,
      }));

      expect(findDropdown().props('items')).toEqual([
        {
          text: 'No access',
          options: [{ text: 'No access', value: -1 }],
          textSrOnly: true,
        },
        { text: 'Custom admin roles', options: roles },
      ]);
    });

    it('clears dropdown button text override', () => {
      // When the dropdown is loading, we set toggleText to the loading message. After it's done loading, we clear
      // toggleText so that the button reverts to its default behavior of showing the selected item's text.
      expect(findDropdown().props('toggleText')).toBe('');
    });

    it('navigates to manage roles page when Manage roles button is clicked', () => {
      findDropdown().vm.$emit('reset');

      expect(visitUrl).toHaveBeenCalledWith('manage/roles/path');
    });

    describe.each(adminRoles)('when $name role is selected', (role) => {
      beforeEach(() => {
        const index = adminRoles.indexOf(role) + 1;
        return findDropdownItemAt(index).trigger('click');
      });

      it('sets hidden input value to role ID', () => {
        expect(getHiddenInputValue()).toBe(getIdFromGraphQLId(role.id).toString());
      });

      describe('permissions list', () => {
        describe.each(role.enabledPermissions.nodes)('for permission $name', (permission) => {
          const index = role.enabledPermissions.nodes.indexOf(permission);

          it('shows check icon', () => {
            expect(findPermissionAt(index).findComponent(GlIcon).props()).toMatchObject({
              name: 'check',
              variant: 'success',
            });
          });

          it('shows permission name', () => {
            expect(findPermissionAt(index).text()).toBe(permission.name);
          });
        });
      });
    });

    describe('No access option', () => {
      it('shows text', () => {
        expect(findDropdownItemAt(0).text()).toBe('No access');
      });

      it('does not bold text', () => {
        expect(findDropdownItemAt(0).find('div').classes('gl-font-bold')).toBe(false);
      });

      describe('when No access is selected', () => {
        beforeEach(() => findDropdownItemAt(0).trigger('click'));

        it('sets hidden input value to empty string', () => {
          expect(getHiddenInputValue()).toBe('');
        });

        it('does not show permissions list', () => {
          expect(wrapper.findByTestId('permissions').exists()).toBe(false);
        });
      });
    });

    describe.each(adminRoles)('$name option', (role) => {
      let nameDiv;
      let descriptionDiv;

      beforeEach(() => {
        // +1 because the first option is "No access".
        const index = adminRoles.indexOf(role) + 1;
        const itemDivs = findDropdownItemAt(index).findAll('div');
        nameDiv = itemDivs.at(0);
        descriptionDiv = itemDivs.at(1);
      });

      it('shows text', () => {
        expect(nameDiv.text()).toBe(role.name);
      });

      it('bolds text and clamps line count', () => {
        expect(nameDiv.classes()).toEqual(['gl-line-clamp-2', 'gl-font-bold']);
      });

      it('shows description', () => {
        expect(descriptionDiv.text()).toBe(role.description);
      });

      it('shows description with expected classes', () => {
        expect(descriptionDiv.classes()).toEqual([
          'gl-mt-2',
          'gl-line-clamp-2',
          'gl-text-sm',
          'gl-text-subtle',
        ]);
      });
    });
  });

  describe('when there are no roles', () => {
    it('shows no roles help message', () => {
      createWrapper({ adminRolesHandler: getAdminRolesHandler([]) });

      expect(findDropdown().text()).toContain('Create admin role to populate this list.');
    });
  });

  describe('when roles could not be loaded', () => {
    beforeEach(() => createWrapper({ adminRolesHandler: jest.fn().mockRejectedValue() }));

    it('shows alert', () => {
      expect(findAlert().text()).toBe('Could not load custom admin roles.');
      expect(findAlert().props()).toMatchObject({
        dismissible: false,
        variant: 'danger',
      });
    });

    it('does not show dropdown', () => {
      expect(findDropdown().exists()).toBe(false);
    });
  });
});

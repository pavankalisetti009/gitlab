import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AdminUsersFilterApp from '~/admin/users/components/admin_users_filter_app.vue';
import { ADMIN_ROLE_TOKEN } from 'ee_jest/admin/users/mock_data';

describe('AdminUsersFilterApp', () => {
  let wrapper;

  const createComponent = ({
    customRoles = true,
    customAdminRoles = true,
    readAdminRole = true,
  }) => {
    wrapper = shallowMount(AdminUsersFilterApp, {
      provide: {
        glLicensedFeatures: { customRoles },
        glFeatures: { customAdminRoles },
        glAbilities: { readAdminRole },
      },
    });
  };

  const findAvailableTokens = () =>
    wrapper.findComponent(GlFilteredSearch).props('availableTokens');

  it.each`
    customRoles | customAdminRoles | readAdminRole
    ${false}    | ${true}          | ${true}
    ${true}     | ${false}         | ${true}
    ${true}     | ${true}          | ${false}
  `(
    'does not include admin role token when customRoles = $customRoles, customAdminRoles = $customAdminRoles',
    ({ customRoles, customAdminRoles, readAdminRole }) => {
      createComponent({ customRoles, customAdminRoles, readAdminRole });

      expect(findAvailableTokens()).not.toContainEqual(ADMIN_ROLE_TOKEN);
    },
  );

  it(`includes admin role token when customRoles = true, customAdminRoles = true`, () => {
    createComponent({ customRoles: true, customAdminRoles: true, readAdminRole: true });

    expect(findAvailableTokens()).toContainEqual(ADMIN_ROLE_TOKEN);
  });
});

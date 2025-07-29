import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupRolesQuery from 'ee/roles_and_permissions/graphql/group_roles.query.graphql';
import RolesCrud from 'ee/roles_and_permissions/components/roles_crud/roles_crud.vue';
import SaasGroupRolesCrud from 'ee/roles_and_permissions/components/roles_crud/saas_group_roles_crud.vue';
import { showRolesFetchError } from 'ee/roles_and_permissions/components/roles_crud/utils';
import { stubComponent } from 'helpers/stub_component';
import { groupRolesResponse, newCustomRoleOption } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('ee/roles_and_permissions/components/roles_crud/utils', () => ({
  ...jest.requireActual('ee/roles_and_permissions/components/roles_crud/utils'),
  showRolesFetchError: jest.fn(),
}));

describe('SaasGroupRolesCrud component', () => {
  let wrapper;

  const defaultRolesQueryHandler = jest.fn().mockResolvedValue(groupRolesResponse);

  const createComponent = ({
    rolesQueryHandler = defaultRolesQueryHandler,
    newRolePath = 'new/role/path',
    groupFullPath = 'group/path',
  } = {}) => {
    wrapper = shallowMountExtended(SaasGroupRolesCrud, {
      apolloProvider: createMockApollo([[groupRolesQuery, rolesQueryHandler]]),
      provide: { newRolePath, groupFullPath },
      stubs: {
        RolesCrud: stubComponent(RolesCrud, { props: ['roles', 'loading', 'newRoleOptions'] }),
      },
    });

    return waitForPromises();
  };

  const findRolesCrud = () => wrapper.findComponent(RolesCrud);

  describe('on page load', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches group roles', () => {
      expect(defaultRolesQueryHandler).toHaveBeenCalledTimes(1);
      expect(defaultRolesQueryHandler).toHaveBeenCalledWith({ fullPath: 'group/path' });
    });

    it('shows roles crud component', () => {
      expect(findRolesCrud().props()).toMatchObject({ roles: {}, loading: true });
    });
  });

  it.each`
    newRolePath        | expectedOptions
    ${null}            | ${[]}
    ${'new/role/path'} | ${[newCustomRoleOption]}
  `(
    'passes expected new role options to roles crud when newRolePath is $newRolePath',
    ({ newRolePath, expectedOptions }) => {
      createComponent({ newRolePath });

      expect(findRolesCrud().props('newRoleOptions')).toEqual(expectedOptions);
    },
  );

  describe('when query is finished', () => {
    beforeEach(() => createComponent());

    it('passes roles to roles crud component', () => {
      expect(findRolesCrud().props('roles')).toEqual(groupRolesResponse.data.group);
    });

    it('shows roles crud component as not loading', () => {
      expect(findRolesCrud().props('loading')).toBe(false);
    });
  });

  describe('when query throws an error', () => {
    beforeEach(() => createComponent({ rolesQueryHandler: jest.fn().mockRejectedValue() }));

    it('shows fetch error', () => {
      expect(showRolesFetchError).toHaveBeenCalledTimes(1);
    });
  });
});

import { GlLink, GlSprintf, GlTabs, GlTab } from '@gitlab/ui';
import RoleTabs from 'ee/roles_and_permissions/components/role_tabs.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import InstanceRolesCrud from 'ee/roles_and_permissions/components/roles_crud/instance_roles_crud.vue';
import SaasGroupRolesCrud from 'ee/roles_and_permissions/components/roles_crud/saas_group_roles_crud.vue';
import SaasAdminRolesCrud from 'ee/roles_and_permissions/components/roles_crud/saas_admin_roles_crud.vue';
import LdapSyncCrud from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_crud.vue';
import { ldapServers as ldapServersData } from '../mock_data';

describe('RoleTabs component', () => {
  let wrapper;

  const createWrapper = ({
    ldapServers = ldapServersData,
    customAdminRoles = true,
    adminModeSettingPath = '',
    isSaas = false,
    groupFullPath = null,
  } = {}) => {
    wrapper = shallowMountExtended(RoleTabs, {
      propsData: { adminModeSettingPath, isSaas },
      provide: {
        ldapServers,
        groupFullPath,
        glFeatures: { customAdminRoles },
      },
      stubs: { GlSprintf },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findDocsLink = () => findPageHeading().findComponent(GlLink);
  const findRolesCrud = () => wrapper.findComponent(InstanceRolesCrud);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findTabAt = (index) => wrapper.findAllComponents(GlTab).at(index);
  const findLdapSyncCrud = () => wrapper.findComponent(LdapSyncCrud);
  const findAdminRoleRecommendation = () => wrapper.findByTestId('admin-mode-recommendation');

  describe('page heading', () => {
    beforeEach(() => createWrapper());

    it('shows heading', () => {
      expect(findPageHeading().props('heading')).toBe('Roles and permissions');
    });

    it('shows description', () => {
      expect(findPageHeading().text()).toBe(
        'Manage which actions users can take with roles and permissions.',
      );
    });

    it('shows docs page link', () => {
      expect(findDocsLink().text()).toBe('roles and permissions');
      expect(findDocsLink().attributes()).toMatchObject({
        href: '/help/user/permissions',
        target: '_blank',
      });
    });
  });

  it.each`
    name            | isSaas   | groupFullPath      | rolesCrud
    ${'instance'}   | ${false} | ${null}            | ${InstanceRolesCrud}
    ${'SaaS group'} | ${true}  | ${'groupFullPath'} | ${SaasGroupRolesCrud}
    ${'SaaS admin'} | ${true}  | ${null}            | ${SaasAdminRolesCrud}
  `(
    'shows expected roles crud component on $name roles and permissions page',
    ({ isSaas, groupFullPath, rolesCrud }) => {
      createWrapper({ isSaas, groupFullPath });

      expect(wrapper.findComponent(rolesCrud).exists()).toBe(true);
    },
  );

  describe.each`
    phrase                                                | options
    ${'when ldap is disabled'}                            | ${{ ldapServers: null }}
    ${'when custom admin roles feature flag is disabled'} | ${{ customAdminRoles: false }}
  `('$phrase', ({ options }) => {
    beforeEach(() => createWrapper(options));

    it('shows roles crud', () => {
      expect(findRolesCrud().exists()).toBe(true);
    });

    it('does not show tabs', () => {
      expect(findTabs().exists()).toBe(false);
    });

    it('does not show ldap sync crud', () => {
      expect(findLdapSyncCrud().exists()).toBe(false);
    });
  });

  describe('when ldap is enabled', () => {
    beforeEach(() => createWrapper());

    it('shows tabs', () => {
      expect(findTabs().props('syncActiveTabWithQueryParams')).toBe(true);
    });

    it('shows roles tab', () => {
      expect(findTabAt(0).attributes('title')).toBe('Roles');
      expect(findTabAt(0).props('queryParamValue')).toBe('roles');
    });

    it('shows ldap tab', () => {
      expect(findTabAt(1).attributes('title')).toBe('LDAP Synchronization');
      expect(findTabAt(1).props('queryParamValue')).toBe('ldap');
    });

    it('shows roles crud in roles tab', () => {
      expect(findTabAt(0).findComponent(InstanceRolesCrud).exists()).toBe(true);
    });

    it('shows ldap sync crud in ldap tab', () => {
      expect(findTabAt(1).findComponent(LdapSyncCrud).exists()).toBe(true);
    });
  });

  it('does not show admin mode recommendation alert by default', () => {
    createWrapper();

    expect(findAdminRoleRecommendation().exists()).toBe(false);
  });

  describe('when enabling admin mode is recommended', () => {
    beforeEach(() => createWrapper({ adminModeSettingPath: 'path/to/admin/mode/setting' }));

    it('shows admin mode recommendation alert', () => {
      expect(findAdminRoleRecommendation().text()).toMatchInterpolatedText(
        'To enhance security, we recommend enabling Admin mode when using custom admin roles. Enabling Admin mode will require users to re-authenticate in GitLab before accessing the Admin area.',
      );
    });

    it('shows link to admin mode setting', () => {
      const link = findAdminRoleRecommendation().findComponent(GlLink);

      expect(link.text()).toBe('enabling Admin mode');
      expect(link.props('href')).toBe('path/to/admin/mode/setting');
    });
  });
});

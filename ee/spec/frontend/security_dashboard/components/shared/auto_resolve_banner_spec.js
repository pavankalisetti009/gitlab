import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlBanner, GlLink, GlSprintf } from '@gitlab/ui';
import AutoResolveBanner from 'ee/security_dashboard/components/shared/auto_resolve_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import projectVulnerabilityManagementPoliciesQuery from 'ee/security_dashboard/components/shared/graphql/first_project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from 'ee/security_dashboard/components/shared/graphql/first_group_vulnerability_management_policies.query.graphql';
import { PROMO_URL } from '~/lib/utils/url_utility';
import { DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import createMockApollo from 'helpers/mock_apollo_helper';

Vue.use(VueApollo);

const getProjectPolicies = (nodes = []) => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Project/1',
      vulnerabilityManagementPolicies: {
        nodes,
      },
    },
  },
});
const groupPolicies = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      vulnerabilityManagementPolicies: {
        nodes: [],
      },
    },
  },
};

describe('AutoResolveBanner', () => {
  useLocalStorageSpy();

  let wrapper;
  let projectHandler;
  let groupHandler;

  const createComponent = ({
    provide = {},
    projectPoliciesResponse = getProjectPolicies(),
    stubs = {},
  } = {}) => {
    projectHandler = jest.fn().mockResolvedValue(projectPoliciesResponse);
    groupHandler = jest.fn().mockResolvedValue(groupPolicies);

    wrapper = shallowMount(AutoResolveBanner, {
      apolloProvider: createMockApollo([
        [projectVulnerabilityManagementPoliciesQuery, projectHandler],
        [groupVulnerabilityManagementPoliciesQuery, groupHandler],
      ]),
      provide: {
        fullPath: 'group-1/project-1',
        dashboardType: DASHBOARD_TYPE_PROJECT,
        ...provide,
      },
      stubs,
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findStorageSync = () => wrapper.findComponent(LocalStorageSync);

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  describe('template', () => {
    it('renders LocalStorageSync component with correct props', () => {
      const storageSync = findStorageSync();

      expect(storageSync.exists()).toBe(true);
      expect(storageSync.props('storageKey')).toBe('auto_resolve_banner_dismissed');
      expect(storageSync.props('value')).toBe(false);
    });

    it('does not render when fetching policies', () => {
      createComponent();

      expect(findBanner().exists()).toBe(false);
    });

    it('renders banner and passes correct props', () => {
      const banner = findBanner();

      expect(banner.exists()).toBe(true);
      expect(banner.props()).toMatchObject({
        title: 'Auto-resolve vulnerabilities that are no longer detected',
        buttonText: 'Go to policies',
        buttonLink: '/group-1/project-1/-/security/policies',
      });
    });

    it('passes correct message', () => {
      const description = wrapper.findComponent(GlSprintf);
      expect(description.attributes('message')).toBe(
        'To automatically resolve vulnerabilities when they are no longer detected by automated scanning, use the new auto-resolve option in your vulnerability management policies. From the %{boldStart}Policies%{boldEnd} page, configure a policy by applying the %{boldStart}Auto-resolve%{boldEnd} option and make sure the policy is linked to the appropriate projects. You can also configure the policy to auto-resolve only the vulnerabilities of a specific severity or from specific security scanners. See the %{linkStart}release post%{linkEnd} for details.',
      );
    });

    it('renders link for release post', async () => {
      createComponent({ stubs: { GlBanner, GlSprintf } });
      await waitForPromises();
      const link = wrapper.findComponent(GlLink);

      expect(link.attributes('href')).toBe(
        `${PROMO_URL}/releases/2024/12/19/gitlab-17-7-released/#auto-resolve-vulnerabilities-when-not-found-in-subsequent-scans`,
      );
      expect(link.props('target')).toBe('_blank');
      expect(link.text()).toBe('release post');
    });
  });

  it('fetches project vulnerability management policies', () => {
    expect(projectHandler).toHaveBeenCalledWith({
      fullPath: 'group-1/project-1',
      relationship: 'INHERITED',
    });
    expect(groupHandler).not.toHaveBeenCalled();
  });

  it('does not show banner if there are existing vulnerability management policies', async () => {
    const projectPoliciesResponse = getProjectPolicies([
      {
        name: 'Resolve all no-longer detected',
      },
    ]);
    createComponent({ projectPoliciesResponse });
    await waitForPromises();
    expect(findBanner().exists()).toBe(false);
  });

  describe('dismissed', () => {
    it('dismisses banner and updates localstorage', async () => {
      findBanner().vm.$emit('close');
      await nextTick();

      expect(findBanner().exists()).toBe(false);
      expect(findStorageSync().props('value')).toBe(true);
    });

    it('does not fetch policies if dismissed earlier', async () => {
      window.localStorage.setItem('auto_resolve_banner_dismissed', 'true');

      createComponent({ stubs: { LocalStorageSync } });
      await waitForPromises();
      expect(projectHandler).not.toHaveBeenCalled();
      expect(groupHandler).not.toHaveBeenCalled();
    });
  });

  describe('group level', () => {
    beforeEach(async () => {
      createComponent({ provide: { dashboardType: DASHBOARD_TYPE_GROUP, fullPath: 'group-1' } });
      await waitForPromises();
    });

    it('fetches group vulnerability management policies', () => {
      expect(groupHandler).toHaveBeenCalledWith({
        fullPath: 'group-1',
        relationship: 'INHERITED',
      });
      expect(projectHandler).not.toHaveBeenCalled();
    });

    it('passes correct button link', () => {
      expect(findBanner().props('buttonLink')).toBe('/groups/group-1/-/security/policies');
    });
  });
});

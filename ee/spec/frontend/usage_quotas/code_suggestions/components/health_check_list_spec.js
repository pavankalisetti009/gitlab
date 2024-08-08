import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSkeletonLoader, GlLoadingIcon, GlCard, GlBadge } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import getCloudConnectorHealthStatus from 'ee/usage_quotas/add_on/graphql/cloud_connector_health_check.query.graphql';

const success = {
  data: {
    cloudConnectorStatus: {
      success: true,
      probeResults: [
        {
          name: 'license_probe',
          success: true,
          message: 'Online Cloud License found',
        },
        {
          name: 'host_probe',
          success: true,
          message: 'customers.gitlab.com reachable',
        },
        {
          name: 'host_probe',
          success: true,
          message: 'cloud.gitlab.com reachable',
        },
      ],
    },
  },
};

const emptySuccess = {
  data: {
    cloudConnectorStatus: {
      success: true,
      probeResults: [],
    },
  },
};

const failure = {
  data: {
    cloudConnectorStatus: {
      success: false,
      probeResults: [
        {
          name: 'license_probe',
          success: true,
          message: 'Online Cloud License found',
        },
        {
          name: 'host_probe',
          success: false,
          message: 'customers.gitlab.com not reachable',
        },
        {
          name: 'host_probe',
          success: true,
          message: 'cloud.gitlab.com reachable',
        },
      ],
    },
  },
};

Vue.use(VueApollo);

describe('HealthCheckList', () => {
  let wrapper;
  let mockApollo;

  const findCard = () => wrapper.findComponent(GlCard);
  const findProbes = () => wrapper.findAllComponents(GlAlert);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusBadge = () => wrapper.findComponent(GlBadge);

  let getHealthStatusSuccess = jest.fn().mockResolvedValue(success);

  const createComponent = ({ data = {} } = {}) => {
    mockApollo = createMockApollo([[getCloudConnectorHealthStatus, getHealthStatusSuccess]]);

    wrapper = shallowMountExtended(HealthCheckList, {
      apolloProvider: mockApollo,
      data() {
        return data;
      },
    });
  };

  afterEach(() => {
    mockApollo = null;
  });

  it('does not get rendered if there are no probes and no loading happening', async () => {
    createComponent();
    await waitForPromises();
    expect(findCard().exists()).toBe(false);
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({
        data: {
          isLoading: true,
        },
      });
    });

    it('shows skeleton loader when loading', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not show probes listing when loading', () => {
      expect(findProbes()).toHaveLength(0);
    });

    it('shows loading icon in footer when loading', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('shows loading text in footer when loading', () => {
      expect(wrapper.text()).toContain('Tests are running...');
    });
  });

  it('does not fetch health status on load', async () => {
    createComponent();
    await waitForPromises();
    expect(getHealthStatusSuccess).not.toHaveBeenCalled();
  });

  describe('runHealthCheck', () => {
    it('fetches health status on demand', async () => {
      createComponent();
      await waitForPromises();

      await wrapper.vm.runHealthCheck();

      expect(getHealthStatusSuccess).toHaveBeenCalled();

      expect(wrapper.text()).toContain('Health check results');

      const probeResults = findProbes().wrappers.map((probe) => probe.text());
      expect(probeResults).toEqual([
        'Online Cloud License found',
        'customers.gitlab.com reachable',
        'cloud.gitlab.com reachable',
      ]);
    });

    it('renders the probes when those are available', async () => {
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();

      expect(findProbes()).toHaveLength(3);
    });

    it('resets the current probes', async () => {
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();

      expect(findProbes()).toHaveLength(3);

      wrapper.vm.runHealthCheck();
      await nextTick();
      expect(findProbes()).toHaveLength(0);
      await waitForPromises();
      expect(findProbes()).toHaveLength(3);
    });

    it('does not render probes if there are none', async () => {
      getHealthStatusSuccess = jest.fn().mockResolvedValue(emptySuccess);
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();

      expect(findProbes()).toHaveLength(0);
    });

    it('emits the event when query succeeds', async () => {
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();
      expect(wrapper.emitted('health-check-completed')).toHaveLength(1);
    });

    it('emits the event when query fails', async () => {
      getHealthStatusSuccess = jest.fn().mockRejectedValue({});
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();
      expect(wrapper.emitted('health-check-completed')).toHaveLength(1);
    });
  });

  describe('the Health Check status', () => {
    it.each([
      ['success', true],
      ['danger', false],
    ])('renders the %s status badge when healthStatus is %s', async (expected, healthStatus) => {
      if (healthStatus) {
        getHealthStatusSuccess = jest.fn().mockResolvedValue(success);
      } else {
        getHealthStatusSuccess = jest.fn().mockResolvedValue(failure);
      }
      createComponent();
      await waitForPromises();
      await wrapper.vm.runHealthCheck();
      expect(findStatusBadge().props('variant')).toBe(expected);
    });
  });
});

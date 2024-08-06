import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';

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

Vue.use(VueApollo);

describe('HealthCheckList', () => {
  let wrapper;
  let mockApollo;

  const findProbes = () => wrapper.findAllComponents(GlAlert);

  let getHealthStatusSuccess = jest.fn().mockResolvedValue(success);

  const createComponent = ({ props } = {}) => {
    mockApollo = createMockApollo([[getCloudConnectorHealthStatus, getHealthStatusSuccess]]);

    wrapper = shallowMountExtended(HealthCheckList, {
      apolloProvider: mockApollo,
      propsData: {
        ...props,
      },
    });
  };

  afterEach(() => {
    mockApollo = null;
  });

  it('fetches health status on load', async () => {
    createComponent();
    await waitForPromises();
    expect(getHealthStatusSuccess).toHaveBeenCalled();

    expect(wrapper.text()).toContain('Health check succeeded');

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
    expect(findProbes()).toHaveLength(3);
  });

  it('does not render probes if there are none', async () => {
    getHealthStatusSuccess = jest.fn().mockResolvedValue(emptySuccess);
    createComponent();
    await waitForPromises();
    expect(findProbes()).toHaveLength(0);
  });
});

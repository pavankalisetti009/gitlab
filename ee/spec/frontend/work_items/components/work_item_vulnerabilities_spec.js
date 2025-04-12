import Vue from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemVulnerabilities from 'ee/work_items/components/work_item_vulnerabilities.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import workItemVulnerabilitiesQuery from 'ee/work_items/graphql/work_item_vulnerabilities.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { vulnerabilitiesWidgetResponse } from '../mock_data';

describe('WorkItemVulnerabilities component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const successHandler = jest.fn().mockResolvedValue(vulnerabilitiesWidgetResponse);

  const createComponent = ({ handler = successHandler } = {}) => {
    wrapper = shallowMountExtended(WorkItemVulnerabilities, {
      apolloProvider: createMockApollo([[workItemVulnerabilitiesQuery, handler]]),
      propsData: {
        workItemId,
      },
    });
  };

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  it('fetches vulnerabilities widget', () => {
    expect(successHandler).toHaveBeenCalledWith({ id: workItemId });
  });

  it('shows count of related vulnerabilities', () => {
    expect(wrapper.text()).toBe('2');
  });
});

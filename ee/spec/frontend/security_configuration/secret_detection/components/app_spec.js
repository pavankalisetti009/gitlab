import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
import App from 'ee/security_configuration/secret_detection/components/app.vue';
import ExclusionList from 'ee/security_configuration/secret_detection/components/exclusion_list.vue';
import ProjectSecurityExclusionQuery from 'ee/security_configuration/secret_detection/graphql/project_security_exclusions.query.graphql';
import EmptyState from 'ee/security_configuration/secret_detection/components/empty_state.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { projectSecurityExclusions } from '../mock_data';

Vue.use(VueApollo);

const mockExclusionListResolver = {
  data: {
    project: {
      id: 'gid://gitlab/Project/7',
      exclusions: {
        nodes: projectSecurityExclusions,
      },
    },
  },
};

const mockEmptyExclusionListResolver = {
  data: { project: { id: 'gid://gitlab/Project/7', exclusions: { nodes: [] } } },
};

describe('App', () => {
  let wrapper;
  let apolloProvider;

  const createComponent = (options = {}) => {
    const { provide = {}, resolver = jest.fn().mockResolvedValue(mockExclusionListResolver) } =
      options;

    apolloProvider = createMockApollo([[ProjectSecurityExclusionQuery, resolver]]);

    wrapper = shallowMount(App, {
      apolloProvider,
      provide: {
        projectFullPath: 'group/project',
        ...provide,
      },
    });
  };

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('renders the component', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('displays loading icon when data is being fetched', async () => {
    createComponent();
    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);

    await waitForPromises();

    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
  });

  it('displays security exclusions after data is fetched', async () => {
    createComponent();
    await waitForPromises();
    expect(wrapper.findComponent(ExclusionList).exists()).toBe(true);
    expect(wrapper.findComponent(ExclusionList).props('exclusions')).toEqual(
      projectSecurityExclusions,
    );
  });

  it('displays empty state when there are no security exclusions', async () => {
    createComponent({
      resolver: jest.fn().mockResolvedValue(mockEmptyExclusionListResolver),
    });
    await waitForPromises();
    expect(wrapper.findComponent(EmptyState).exists()).toBe(true);
  });
});

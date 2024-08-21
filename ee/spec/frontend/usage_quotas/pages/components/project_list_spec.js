import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PagesProjects from 'ee/usage_quotas/pages/components/project_list.vue';
import ProjectView from 'ee/usage_quotas/pages/components/project.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import GetNamespacePagesDeployments from 'ee/usage_quotas/pages/graphql/pages_deployments.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getNamespacePagesDeploymentsMockData,
  getEmptyNamespacePagesDeploymentsMockData,
  mockError,
} from './mock_data';

jest.mock(
  '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg?url',
  () => 'mocked-svg-url',
);

Vue.use(VueApollo);

describe('PagesProjects', () => {
  const mockProjects = getNamespacePagesDeploymentsMockData.data.namespace.projects.nodes;
  let wrapper;
  let mockApollo;

  const createComponent = (
    queryHandler = jest.fn().mockResolvedValue(getNamespacePagesDeploymentsMockData),
    props = {},
  ) => {
    mockApollo = createMockApollo([[GetNamespacePagesDeployments, queryHandler]]);

    return shallowMount(PagesProjects, {
      propsData: props,
      provide: {
        fullPath: 'test/path',
      },
      apolloProvider: mockApollo,
    });
  };

  it('calls the apollo query with the expected variables', () => {
    const handler = jest.fn();

    wrapper = createComponent(handler, { sort: 'UPDATED_ASC' });

    expect(handler).toHaveBeenCalledWith({
      fullPath: 'test/path',
      first: 15,
      sort: 'UPDATED_ASC',
      active: true,
      versioned: true,
    });
  });

  it('renders loading icon while loading', () => {
    wrapper = createComponent(Promise);

    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
  });

  it('renders project rows when there are results', async () => {
    wrapper = createComponent();

    await waitForPromises();

    const projectRows = wrapper.findAllComponents(ProjectView);
    expect(projectRows).toHaveLength(2);
    expect(projectRows.at(0).props('project')).toEqual(mockProjects[0]);
    expect(projectRows.at(1).props('project')).toEqual(mockProjects[2]);
  });

  it('does not show projects with no pages deployments', async () => {
    wrapper = createComponent();

    await waitForPromises();

    const projectRows = wrapper.findAllComponents(ProjectView);
    expect(projectRows.wrappers.map((w) => w.props('project').id)).not.toContain(
      'gid://gitlab/Project/3',
    );
  });

  it('renders error alert when apollo has an error', async () => {
    wrapper = createComponent(jest.fn().mockRejectedValue(mockError));

    await waitForPromises();

    const alert = wrapper.findComponent(GlAlert);
    expect(alert.exists()).toBe(true);
    expect(alert.props('variant')).toBe('danger');
    expect(alert.text()).toContain('An error occurred trying to load the Pages deployments.');
  });

  it('renders empty state when the project list is empty', async () => {
    wrapper = createComponent(
      jest.fn().mockResolvedValue(getEmptyNamespacePagesDeploymentsMockData),
    );

    await waitForPromises();

    const emptyState = wrapper.findComponent(GlEmptyState);
    expect(emptyState.exists()).toBe(true);
    expect(emptyState.props('title')).toBe('No projects found');
    expect(emptyState.props('svgPath')).toBe('mocked-svg-url');
  });
});

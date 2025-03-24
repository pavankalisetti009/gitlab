import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlIntersperse,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import getProjectComponentVersions from 'ee/dependencies/graphql/project_component_versions.query.graphql';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import createStore from 'ee/dependencies/store';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';

Vue.use(VueApollo);
jest.mock('~/alert');

const TEST_VERSIONS = [
  {
    id: 'gid://gitlab/Sbom::ComponentVersion/1',
    version: '1.1.1',
  },
  {
    id: 'gid://gitlab/Sbom::ComponentVersion/2',
    version: '2.0.0',
  },
];
const FULL_PATH = 'gitlab-org/project-1';

describe('ee/dependencies/components/filtered_search/tokens/version_token.vue', () => {
  let wrapper;
  let store;
  let handlerMocks;

  const createVuexStore = () => {
    store = createStore();
  };

  const createMockApolloProvider = ({ handlers = {} } = {}) => {
    const defaultHandlers = {
      projectHandler: jest.fn().mockResolvedValue({
        data: {
          namespace: {
            id: 'gid://gitlab/Project/1',
            componentVersions: {
              nodes: TEST_VERSIONS,
            },
          },
        },
      }),
    };
    handlerMocks = { ...defaultHandlers, ...handlers };

    const requestHandlers = [[getProjectComponentVersions, handlerMocks.projectHandler]];
    return createMockApollo(requestHandlers);
  };

  const createComponent = (handlers = {}) => {
    wrapper = shallowMountExtended(VersionToken, {
      store,
      apolloProvider: createMockApolloProvider(handlers),
      provide: {
        projectFullPath: FULL_PATH,
      },
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findFirstSearchSuggestionIcon = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);
  const selectVersion = (versionId) => {
    findFilteredSearchToken().vm.$emit('select', getIdFromGraphQLId(versionId));
    return nextTick();
  };

  beforeEach(() => {
    createVuexStore();
    createComponent();
  });

  describe('when the component is initially rendered', () => {
    it('passes the correct props to the GlFilteredSearchToken', () => {
      expect(findFilteredSearchToken().props()).toMatchObject({
        config: { multiSelect: true },
        value: { data: [] },
        viewOnly: true,
        active: false,
      });
    });
  });

  describe('when no components are selected', () => {
    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, filter by one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });

    it('does not fetch versions', () => {
      expect(handlerMocks.projectHandler).not.toHaveBeenCalled();
    });
  });

  describe('when multiple components are selected', () => {
    beforeEach(() => {
      store.state.allDependencies.componentIds = ['component-1', 'component-2'];
    });

    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, select exactly one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });

    it('does not fetch versions', () => {
      expect(handlerMocks.projectHandler).not.toHaveBeenCalled();
    });
  });

  describe('when exactly one component is selected', () => {
    const componentIds = ['component-1'];
    beforeEach(() => {
      store.state.allDependencies.componentIds = componentIds;
    });

    it('does not show any guidance messages', () => {
      expect(findFilteredSearchToken().text()).toBe('');
    });

    it('sets viewOnly prop to false', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(false);
    });

    it('shows a loading indicator while fetching the list of versions', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('fetches the list of versions', () => {
      expect(handlerMocks.projectHandler).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: FULL_PATH, componentId: componentIds[0] }),
      );
    });
  });

  describe('when the versions have been fetched successfully', () => {
    beforeEach(async () => {
      store.state.allDependencies.componentIds = ['component-1'];
      await waitForPromises();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('shows a list of versions', () => {
      expect(wrapper.findAllComponents(GlFilteredSearchSuggestion)).toHaveLength(
        TEST_VERSIONS.length,
      );
      expect(wrapper.text()).toContain(TEST_VERSIONS[0].version);
      expect(wrapper.text()).toContain(TEST_VERSIONS[1].version);
    });

    describe('when a user selects versions to be filtered', () => {
      it('displays a check-icon next to the selected project', async () => {
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectVersion(TEST_VERSIONS[0].id);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('does not display check-icon if unchecked again', async () => {
        await selectVersion(TEST_VERSIONS[0].id);
        await selectVersion(TEST_VERSIONS[0].id);
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected versions', async () => {
        await selectVersion(TEST_VERSIONS[0].id);
        await selectVersion(TEST_VERSIONS[1].id);

        expect(wrapper.findByTestId('selected-versions').text()).toMatchInterpolatedText(
          `${TEST_VERSIONS[0].version}, ${TEST_VERSIONS[1].version}`,
        );
      });
    });
  });

  describe('when there is an error fetching the versions', () => {
    beforeEach(async () => {
      createComponent({
        handlers: {
          projectHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        },
      });
      store.state.allDependencies.componentIds = ['component-1'];

      await waitForPromises();
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'There was an error fetching the versions for the selected component. Please try again later.',
      });
    });
  });
});

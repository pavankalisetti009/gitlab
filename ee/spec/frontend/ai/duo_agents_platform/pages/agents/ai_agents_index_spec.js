import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiAgentsIndex from 'ee/ai/duo_agents_platform/pages/agents/ai_agents_index.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import projectAiCatalogAgentsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_agents.query.graphql';
import {
  mockAiCatalogAgentResponse,
  mockAgentsWithConfig,
  mockBaseItemConsumer,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockPageInfo,
  mockProjectUserPermissionsResponse,
} from 'ee_jest/ai/catalog/mock_data';
import { mockProjectAgentsResponse, mockProjectItemsEmptyResponse } from '../../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiAgentsIndex', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };
  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockProjectPath = '/mock-group/test-project';
  const mockProjectAgentsQueryHandler = jest.fn().mockResolvedValue(mockProjectAgentsResponse);
  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo([
      [projectAiCatalogAgentsQuery, mockProjectAgentsQueryHandler],
      [aiCatalogProjectUserPermissionsQuery, mockUserPermissionsQueryHandler],
      [aiCatalogAgentQuery, mockAgentQueryHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiAgentsIndex, {
      apolloProvider: mockApollo,
      provide: {
        projectId: mockProjectId,
        projectPath: mockProjectPath,
        exploreAiCatalogPath: '/explore/ai-catalog',
      },
      mocks: {
        $router: mockRouter,
        $route,
        $toast: mockToast,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('renders AiCatalogList component', async () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual(mockAgentsWithConfig);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    describe('when there are no agents', () => {
      beforeEach(async () => {
        mockProjectAgentsQueryHandler.mockResolvedValueOnce(mockProjectItemsEmptyResponse);

        await waitForPromises();
      });

      it('renders empty state with correct props', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Use agents in your project.',
          description: 'Use agents to automate tasks and answer questions.',
        });
      });
    });
  });

  describe('Apollo queries', () => {
    it('fetches list data', () => {
      expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        projectPath: mockProjectPath,
        enabled: true,
        allAvailable: true,
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });

    describe('disabling an agent', () => {
      const item = mockAgentsWithConfig[0];
      const disableAgent = () => findAiCatalogList().props('disableFn')(item);

      it('calls delete consumer mutation', () => {
        disableAgent();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: mockBaseItemConsumer.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows a toast message and refetches the list', async () => {
          disableAgent();

          await waitForPromises();

          expect(mockProjectAgentsQueryHandler).toHaveBeenCalledTimes(3);
          expect(mockToast.show).toHaveBeenCalledWith('Agent disabled in this project.');
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows alert with error', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );

          disableAgent();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to disable agent. You do not have permission to disable this item.',
          ]);
        });
      });

      describe('when request fails', () => {
        it('shows alert with error and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('Request failed'));

          disableAgent();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to disable agent. Error: Request failed',
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to list component', () => {
      expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging backward', async () => {
      findAiCatalogList().vm.$emit('prev-page');
      await nextTick();
      expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        projectPath: mockProjectPath,
        enabled: true,
        allAvailable: true,
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', async () => {
      findAiCatalogList().vm.$emit('next-page');
      await nextTick();
      expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        projectPath: mockProjectPath,
        enabled: true,
        allAvailable: true,
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });
});

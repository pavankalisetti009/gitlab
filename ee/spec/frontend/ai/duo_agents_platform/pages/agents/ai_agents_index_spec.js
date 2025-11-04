import Vue from 'vue';
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
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAiCatalogAgentResponse,
  mockBaseAgent,
  mockBaseItemConsumer,
  mockConfiguredAgentsResponse,
  mockConfiguredItemsEmptyResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockPageInfo,
  mockProjectUserPermissionsResponse,
} from 'ee_jest/ai/catalog/mock_data';

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
  const mockConfiguredAgentsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockConfiguredAgentsResponse);
  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredAgentsQueryHandler],
      [aiCatalogProjectUserPermissionsQuery, mockUserPermissionsQueryHandler],
      [aiCatalogAgentQuery, mockAgentQueryHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiAgentsIndex, {
      apolloProvider: mockApollo,
      provide: {
        projectId: mockProjectId,
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
      const expectedItem = {
        ...mockBaseAgent,
        itemConsumer: mockBaseItemConsumer,
      };
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual([expectedItem]);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    describe('when there are no agents', () => {
      beforeEach(async () => {
        mockConfiguredAgentsQueryHandler.mockResolvedValueOnce(mockConfiguredItemsEmptyResponse);

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
      expect(mockConfiguredAgentsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeInherited: false,
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });

    describe('deleting an agent', () => {
      const item = {
        ...mockBaseAgent,
        itemConsumer: mockBaseItemConsumer,
      };
      const deleteAgent = () => findAiCatalogList().props('deleteFn')(item);

      it('calls delete mutation', () => {
        deleteAgent();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: mockBaseItemConsumer.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows a toast message and refetches the list', async () => {
          deleteAgent();

          await waitForPromises();

          expect(mockConfiguredAgentsQueryHandler).toHaveBeenCalledTimes(2);
          expect(mockToast.show).toHaveBeenCalledWith('Agent removed from this project.');
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows alert with error', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );

          deleteAgent();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to remove agent. You do not have permission to delete this item.',
          ]);
        });
      });

      describe('when request fails', () => {
        it('shows alert with error and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('Request failed'));

          deleteAgent();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to remove agent. Error: Request failed',
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

    it('refetches query with correct variables when paging backward', () => {
      findAiCatalogList().vm.$emit('prev-page');
      expect(mockConfiguredAgentsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeInherited: false,
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', () => {
      findAiCatalogList().vm.$emit('next-page');
      expect(mockConfiguredAgentsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeInherited: false,
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });
});

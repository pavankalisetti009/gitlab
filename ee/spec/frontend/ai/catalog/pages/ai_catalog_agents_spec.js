import VueApollo from 'vue-apollo';
import Vue from 'vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import { AI_CATALOG_AGENTS_DUPLICATE_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockAgents,
  mockCatalogItemsResponse,
  mockCatalogAgentDeleteResponse,
  mockCatalogAgentDeleteErrorResponse,
  mockAiCatalogAgentResponse,
  mockPageInfo,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogAgents', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };

  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const deleteCatalogItemMutationHandler = jest.fn();
  const mockToast = {
    show: jest.fn(),
  };
  const mockSetItemToDuplicateMutation = jest.fn();

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo(
      [
        [aiCatalogAgentQuery, mockAgentQueryHandler],
        [aiCatalogAgentsQuery, mockCatalogItemsQueryHandler],
        [deleteAiCatalogAgentMutation, deleteCatalogItemMutationHandler],
      ],
      {
        Mutation: {
          setItemToDuplicate: mockSetItemToDuplicateMutation,
        },
      },
    );

    wrapper = shallowMountExtended(AiCatalogAgents, {
      apolloProvider: mockApollo,
      mocks: {
        $toast: mockToast,
        $router: mockRouter,
        $route,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findAiCatalogItemDrawer = () => wrapper.findComponent(AiCatalogItemDrawer);
  const agentNotFoundErrorMessage = 'Agent not found.';

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('component rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('renders AiCatalogList component', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.exists()).toBe(true);
    });

    it('passes correct props to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('items')).toEqual(mockAgents);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    it('renders item drawer closed by default', () => {
      expect(findAiCatalogItemDrawer().exists()).toBe(true);
      expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
    });
  });

  describe('when loading', () => {
    it('passes loading state with boolean true to AiCatalogList', () => {
      createComponent();
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);
    });
  });

  describe('with agent data', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('fetches list data', () => {
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalled();
    });

    it('passes agent data to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('items')).toEqual(mockAgents);
      expect(catalogList.props('items')).toHaveLength(3);
    });

    it('passes isLoading as false when not loading', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(false);
    });
  });

  describe('when linking directly to an agent via URL', () => {
    describe('when agent exists in the list', () => {
      let resolveDetails;

      beforeEach(async () => {
        // keep state as loading until we manually resolve
        mockAgentQueryHandler.mockReturnValue(
          new Promise((resolve) => {
            resolveDetails = resolve;
          }),
        );
        await createComponent({
          $route: { query: { show: getIdFromGraphQLId(mockAgents[0].id) } },
        });
        await waitForPromises();
      });

      it('fetches agent details with correct GraphQL ID', () => {
        expect(mockAgentQueryHandler).toHaveBeenCalledTimes(1);
        expect(mockAgentQueryHandler).toHaveBeenCalledWith({
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, getIdFromGraphQLId(mockAgents[0].id)),
        });
      });

      it('opens the drawer immediately when agent is in list', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
      });

      it('shows loading state initially', () => {
        expect(findAiCatalogItemDrawer().props('isItemDetailsLoading')).toBe(true);
      });

      it('provides agent from list while details are loading', () => {
        const activeItem = findAiCatalogItemDrawer().props('activeItem');
        expect(activeItem).toEqual(mockAgents[0]);
      });

      it('displays fetched agent details after loading completes', async () => {
        // resolve to complete loading
        resolveDetails(mockAiCatalogAgentResponse);
        await waitForPromises();

        expect(findAiCatalogItemDrawer().props()).toMatchObject({
          isOpen: true,
          isItemDetailsLoading: false,
          activeItem: mockAgent,
        });
      });

      describe('when closing the drawer', () => {
        beforeEach(() => {
          findAiCatalogItemDrawer().vm.$emit('close');
        });

        it('removes show query param from URL', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({
            path: undefined,
            query: {},
          });
        });
      });
    });

    describe('when agent is not in list and needs to be fetched', () => {
      beforeEach(() => {
        // Mock a list without the requested agent
        mockCatalogItemsQueryHandler.mockResolvedValue({
          data: {
            aiCatalogItems: {
              nodes: mockAgents.slice(1),
              pageInfo: mockPageInfo,
            },
          },
        });

        mockAgentQueryHandler.mockResolvedValue(mockAiCatalogAgentResponse);

        createComponent({
          $route: { query: { show: getIdFromGraphQLId(mockAgents[0].id) } },
        });
      });

      it('does not open drawer while loading', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });

      it('opens drawer after agent details load', async () => {
        await waitForPromises();
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
      });
    });

    describe('when user has no permission to view agent', () => {
      beforeEach(async () => {
        // Mock response with null agent (no permissions)
        mockAgentQueryHandler.mockResolvedValue({
          data: {
            aiCatalogItem: null,
          },
        });

        await createComponent({ $route: { query: { show: 'unauthorized-id' } } });
        await waitForPromises();
      });

      it('does not open the drawer', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });

      it('closes the drawer automatically', () => {
        expect(mockRouter.push).toHaveBeenCalledWith({
          path: undefined,
          query: {},
        });
      });

      it('displays permission error message', () => {
        expect(findErrorsAlert().props('errors')).toStrictEqual([agentNotFoundErrorMessage]);
      });

      it('does not log to Sentry for permission issues', () => {
        expect(Sentry.captureException).not.toHaveBeenCalled();
      });
    });

    describe('when agent fetch fails with error', () => {
      beforeEach(async () => {
        mockAgentQueryHandler.mockRejectedValue(new Error('Network error'));
        await createComponent({ $route: { query: { show: 'invalid-id' } } });
        await waitForPromises();
      });

      it('does not open the drawer', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });

      it('closes the drawer automatically', () => {
        expect(mockRouter.push).toHaveBeenCalledWith({
          path: undefined,
          query: {},
        });
      });

      it('displays error message', () => {
        expect(findErrorsAlert().props('errors')).toStrictEqual(['Network error']);
      });

      it('logs error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on deleting an agent', () => {
    const deleteAgent = (index = 0) => findAiCatalogList().props('deleteFn')(mockAgents[index]);

    beforeEach(() => {
      createComponent();
    });

    it('calls delete mutation', () => {
      deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogAgentDeleteResponse);

      deleteAgent();

      expect(deleteCatalogItemMutationHandler).toHaveBeenCalledWith({ id: mockAgents[0].id });
    });

    describe('when request succeeds', () => {
      it('shows a toast message and refetches the list', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogAgentDeleteResponse);

        deleteAgent();

        await waitForPromises();

        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledTimes(2);
        expect(mockToast.show).toHaveBeenCalledWith('Agent deleted successfully.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows alert with error', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogAgentDeleteErrorResponse);

        deleteAgent();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toStrictEqual([
          'Failed to delete agent. You do not have permission to delete this AI agent.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows alert with error and captures exception', async () => {
        deleteCatalogItemMutationHandler.mockRejectedValue(new Error('Request failed'));

        deleteAgent();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toStrictEqual([
          'Failed to delete agent. Error: Request failed',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on duplicating an agent', () => {
    const duplicateAgent = async (index = 1) => {
      await waitForPromises();
      await wrapper.vm.handleDuplicate(mockAgents[index]);
    };

    beforeEach(() => {
      createComponent();
    });

    it('calls setItemToDuplicate mutation with correct variables', async () => {
      mockSetItemToDuplicateMutation.mockResolvedValue({ data: {} });

      await duplicateAgent();

      expect(mockSetItemToDuplicateMutation).toHaveBeenCalledWith(
        {},
        {
          item: {
            id: getIdFromGraphQLId(mockAgents[1].id),
            type: 'AGENT',
            data: mockAgents[1],
          },
        },
        expect.anything(),
        expect.anything(),
      );
    });

    describe('when request succeeds', () => {
      it('navigates to duplicate route', async () => {
        mockSetItemToDuplicateMutation.mockResolvedValue({ data: {} });

        await duplicateAgent();

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
          params: { id: getIdFromGraphQLId(mockAgents[1].id) },
        });
      });
    });

    describe('when agent is not found', () => {
      it('shows error message and logs to Sentry', async () => {
        await duplicateAgent(3);

        expect(findErrorsAlert().props('errors')).toStrictEqual([agentNotFoundErrorMessage]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('pagination', () => {
    it('passes pageInfo to list component', async () => {
      createComponent();
      await waitForPromises();

      expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging backward', async () => {
      createComponent();
      await waitForPromises();

      findAiCatalogList().vm.$emit('prev-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', async () => {
      createComponent();
      await waitForPromises();

      findAiCatalogList().vm.$emit('next-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });
});

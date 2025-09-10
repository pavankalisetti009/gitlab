import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import { AI_CATALOG_AGENTS_DUPLICATE_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  TRACK_EVENT_TYPE_AGENT,
} from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockAgents,
  mockCatalogItemsResponse,
  mockCatalogAgentDeleteResponse,
  mockCatalogAgentDeleteErrorResponse,
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentResponse2,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockPageInfo,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils');

Vue.use(VueApollo);

describe('AiCatalogAgents', () => {
  let wrapper;
  let mockApollo;
  let mockRoute;

  const mockRouter = {
    push: jest.fn(),
  };

  const mockToast = {
    show: jest.fn(),
  };
  const mockSetItemToDuplicateMutation = jest.fn();

  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const createAiCatalogItemConsumerHandler = jest.fn();
  const deleteCatalogItemMutationHandler = jest.fn();

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ $route = { query: {} } } = {}) => {
    isLoggedIn.mockReturnValue(true);

    mockRoute = Vue.observable({
      query: $route.query,
    });

    mockApollo = createMockApollo(
      [
        [aiCatalogAgentQuery, mockAgentQueryHandler],
        [aiCatalogAgentsQuery, mockCatalogItemsQueryHandler],
        [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
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
        $route: mockRoute,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findAiCatalogItemDrawer = () => wrapper.findComponent(AiCatalogItemDrawer);
  const findAiCatalogItemConsumerModal = () => wrapper.findComponent(AiCatalogItemConsumerModal);
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

  describe('on adding an agent to project', () => {
    const openModal = async () => {
      const firstItemAction = findAiCatalogList()
        .props('itemTypeConfig')
        .actionItems(mockAgents[0])[0];
      // We pass the function down to child components. Because we use shallowMount
      // we cannot trigger the action which would call the function. So we call it
      // using the properties.
      firstItemAction.action();
      await nextTick();
    };

    beforeEach(async () => {
      mockCatalogItemsQueryHandler.mockResolvedValue(mockCatalogItemsResponse);
      createComponent();
      await waitForPromises();
    });

    it('opens the modal on button click', async () => {
      expect(findAiCatalogItemConsumerModal().exists()).toBe(false);
      await openModal();

      expect(findAiCatalogItemConsumerModal().exists()).toBe(true);
    });

    describe('when the modal is open', () => {
      beforeEach(async () => {
        await openModal();
      });

      it('removes the component once it emits the hide event', async () => {
        findAiCatalogItemConsumerModal().vm.$emit('hide');
        await nextTick();

        expect(findAiCatalogItemConsumerModal().exists()).toBe(false);
      });

      describe('and the form is submitted', () => {
        const createConsumer = () => findAiCatalogItemConsumerModal().vm.$emit('submit');

        describe('when adding to project request succeeds', () => {
          it('shows a toast message', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateSuccessProjectResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(mockToast.show).toHaveBeenCalledWith('Agent added successfully to Test.');
          });
        });

        describe('when request succeeds but returns errors', () => {
          it('shows alert with error', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateErrorResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(findErrorsAlert().props('errors')).toEqual([
              `Agent could not be added: ${mockAgent.name}`,
              'Item already configured.',
            ]);
          });
        });

        describe('when request fails', () => {
          it('shows alert with error and captures exception', async () => {
            createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('Request failed'));

            createConsumer();
            await waitForPromises();

            expect(findErrorsAlert().props('errors')).toEqual([
              'The agent could not be added to the project. Try again. Error: Request failed',
            ]);
            expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          });
        });
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

  describe('tracking events', () => {
    describe('when component is mounted without show query param', () => {
      beforeEach(() => {
        createComponent();
      });

      it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX} event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });
    });

    describe('when component is mounted with show query param', () => {
      beforeEach(async () => {
        mockAgentQueryHandler.mockResolvedValue(mockAiCatalogAgentResponse);
        createComponent({ $route: { query: { show: getIdFromGraphQLId(mockAgents[0].id) } } });
        await waitForPromises();
      });

      it('does not track the index event immediately on mount', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });

      it('tracks the detail event for the initial show param', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });

      it('waits for the query param to be removed before tracking the index event', async () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        mockRoute.query = {};
        await nextTick();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });
    });

    describe('when show query param changes', () => {
      beforeEach(async () => {
        mockAgentQueryHandler.mockResolvedValue(mockAiCatalogAgentResponse);
        createComponent({ $route: { query: { show: getIdFromGraphQLId(mockAgents[0].id) } } });
        await waitForPromises();
      });

      it('tracks the detail event for every show query param change', async () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );

        mockAgentQueryHandler.mockResolvedValue(mockAiCatalogAgentResponse2);
        mockRoute.query = { show: getIdFromGraphQLId(mockAgents[1].id) };
        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );

        expect(trackEventSpy).toHaveBeenCalledTimes(2);
      });

      it('does not track the index event more than once', async () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        mockRoute.query = {};
        await nextTick();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );

        mockRoute.query = { show: getIdFromGraphQLId(mockAgents[0].id) };
        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );

        trackEventSpy.mockClear();
        mockRoute.query = {};
        await nextTick();

        expect(trackEventSpy).not.toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });
    });
  });
});

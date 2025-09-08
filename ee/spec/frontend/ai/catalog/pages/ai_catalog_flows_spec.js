import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import {
  mockFlow,
  mockAiCatalogFlowResponse,
  mockCatalogFlowsResponse,
  mockCatalogFlowDeleteResponse,
  mockCatalogFlowDeleteErrorResponse,
  mockAiCatalogItemConsumerCreateSuccessGroupResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockFlows,
  mockPageInfo,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogFlows', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };
  const mockToast = {
    show: jest.fn(),
  };

  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);
  const deleteCatalogItemMutationHandler = jest.fn();
  const createAiCatalogItemConsumerHandler = jest.fn();

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [aiCatalogFlowsQuery, mockCatalogItemsQueryHandler],
      [deleteAiCatalogFlowMutation, deleteCatalogItemMutationHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogFlows, {
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
  const findAiCatalogItemConsumerModal = () => wrapper.findComponent(AiCatalogItemConsumerModal);
  const findFirstItemActions = () =>
    findAiCatalogList().props('itemTypeConfig').actionItems(mockFlows[0])[0];

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('passes correct props to AiCatalogList', async () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual(mockFlows);
      expect(catalogList.props('isLoading')).toBe(false);
    });
  });

  describe('Apollo queries', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches list data', () => {
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });
  });

  describe('when linking directly to a flow via URL', () => {
    describe('when flow exists in the list', () => {
      let resolveDetails;

      beforeEach(async () => {
        // keep state as loading until we manually resolve
        mockFlowQueryHandler.mockReturnValue(
          new Promise((resolve) => {
            resolveDetails = resolve;
          }),
        );
        createComponent({ $route: { query: { show: getIdFromGraphQLId(mockFlows[0].id) } } });
        await waitForPromises();
      });

      it('fetches flow details with correct GraphQL ID', () => {
        expect(mockFlowQueryHandler).toHaveBeenCalledTimes(1);
        expect(mockFlowQueryHandler).toHaveBeenCalledWith({
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, mockFlows[0].id),
        });
      });

      it('opens the drawer immediately when flow is in list', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
      });

      it('shows loading state initially', () => {
        expect(findAiCatalogItemDrawer().props('isItemDetailsLoading')).toBe(true);
      });

      it('provides flow from list while details are loading', () => {
        const activeItem = findAiCatalogItemDrawer().props('activeItem');
        expect(activeItem).toEqual(mockFlows[0]);
      });

      it('displays fetched flow details after loading completes', async () => {
        // resolve to complete loading
        resolveDetails(mockAiCatalogFlowResponse);
        await waitForPromises();

        expect(findAiCatalogItemDrawer().props()).toMatchObject({
          isOpen: true,
          isItemDetailsLoading: false,
          activeItem: mockFlow,
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

        it('updates router', () => {
          expect(mockRouter.push.mock.calls[0][0].query.show).toBeUndefined();
        });
      });
    });

    describe('when flow is not in list and needs to be fetched', () => {
      beforeEach(() => {
        // Mock a list without the requested flow
        mockCatalogItemsQueryHandler.mockResolvedValue({
          data: {
            aiCatalogItems: {
              nodes: mockFlows.slice(1),
              pageInfo: mockPageInfo,
            },
          },
        });

        mockFlowQueryHandler.mockResolvedValue(mockAiCatalogFlowResponse);

        createComponent({ $route: { query: { show: getIdFromGraphQLId(mockFlows[0].id) } } });
      });

      it('does not open drawer while loading', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });

      it('opens drawer after flow details load', async () => {
        await waitForPromises();
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
      });
    });

    describe('when user has no permission to view flow', () => {
      beforeEach(async () => {
        // Mock response with null flow (no permissions)
        mockFlowQueryHandler.mockResolvedValue({
          data: {
            aiCatalogItem: null,
          },
        });

        createComponent({ $route: { query: { show: 'unauthorized-id' } } });
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
        expect(findErrorsAlert().props('errors')).toEqual(['Flow not found.']);
      });

      it('does not log to Sentry for permission issues', () => {
        expect(Sentry.captureException).not.toHaveBeenCalled();
      });
    });

    describe('when flow fetch fails with error', () => {
      beforeEach(async () => {
        mockFlowQueryHandler.mockRejectedValue(new Error('Network error'));
        createComponent({ $route: { query: { show: 'invalid-id' } } });
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
        expect(findErrorsAlert().props('errors')).toEqual(['Network error']);
      });

      it('logs error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on deleting a flow', () => {
    const deleteFlow = (index = 0) => findAiCatalogList().props('deleteFn')(mockFlows[index]);

    beforeEach(() => {
      createComponent();
    });

    it('calls delete mutation', () => {
      deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogFlowDeleteResponse);

      deleteFlow();

      expect(deleteCatalogItemMutationHandler).toHaveBeenCalledWith({ id: mockFlows[0].id });
    });

    describe('when request succeeds', () => {
      it('shows a toast message and refetches the list', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogFlowDeleteResponse);

        deleteFlow();

        await waitForPromises();

        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledTimes(2);
        expect(mockToast.show).toHaveBeenCalledWith('Flow deleted successfully.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows alert with error', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogFlowDeleteErrorResponse);

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. You do not have permission to delete this AI flow.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows alert with error and captures exception', async () => {
        deleteCatalogItemMutationHandler.mockRejectedValue(new Error('Request failed'));

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. Error: Request failed',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
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
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', () => {
      findAiCatalogList().vm.$emit('next-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });

  describe('when clicking on the button to create a consumer', () => {
    async function openModal() {
      // We pass the function down to child components. Because we use shallowMount
      // we cannot trigger the action which would call the function. So we call it
      // it using the properties.
      findFirstItemActions().action();
      await nextTick();
    }

    beforeEach(async () => {
      mockCatalogItemsQueryHandler.mockResolvedValue(mockCatalogFlowsResponse);
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
        const createConsumer = () =>
          findAiCatalogItemConsumerModal().vm.$emit('submit', { targetType: 'project' });

        describe('when adding to project request succeeds', () => {
          it('shows a toast message', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateSuccessProjectResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(mockToast.show).toHaveBeenCalledWith('Flow added successfully to Test.');
          });
        });

        describe('when adding to group request succeeds', () => {
          it('shows a toast message', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateSuccessGroupResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(mockToast.show).toHaveBeenCalledWith('Flow added successfully to GitLab Duo.');
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
              `Flow could not be added: ${mockFlow.name}`,
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
              'The flow could not be enabled. Try again. Error: Request failed',
            ]);
            expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          });
        });
      });
    });
  });
});

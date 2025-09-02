import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiFlows from 'ee/ai/duo_agents_platform/pages/flows/ai_flows.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAiCatalogFlowResponse,
  mockBaseFlow,
  mockBaseItemConsumer,
  mockConfiguredFlowsResponse,
  mockConfiguredFlowsEmptyResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiFlows', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };
  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockConfiguredFlowsQueryHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);
  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredFlowsQueryHandler],
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiFlows, {
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
    it('renders PageHeading component', () => {
      expect(wrapper.findComponent(PageHeading).exists()).toBe(true);
    });

    it('renders AiCatalogList component', async () => {
      const expectedItem = {
        ...mockBaseFlow,
        itemConsumer: mockBaseItemConsumer,
      };
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual([expectedItem]);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    describe('when there are no flows', () => {
      beforeEach(async () => {
        mockConfiguredFlowsQueryHandler.mockResolvedValueOnce(mockConfiguredFlowsEmptyResponse);

        await waitForPromises();
      });

      it('renders empty state with correct props', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Use AI Flows in your project.',
          description: 'Automate tasks and processes using AI Flows.',
        });
      });
    });
  });

  describe('Apollo queries', () => {
    it('fetches list data', () => {
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });

    describe('deleting a flow', () => {
      const item = {
        ...mockBaseFlow,
        itemConsumer: mockBaseItemConsumer,
      };
      const deleteFlow = () => findAiCatalogList().props('deleteFn')(item);

      it('calls delete mutation', () => {
        deleteFlow();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: mockBaseItemConsumer.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows a toast message and refetches the list', async () => {
          deleteFlow();

          await waitForPromises();

          expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledTimes(2);
          expect(mockToast.show).toHaveBeenCalledWith(
            'Flow removed successfully from this project.',
          );
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows alert with error', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );

          deleteFlow();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to remove flow. You do not have permission to delete this AI flow.',
          ]);
        });
      });

      describe('when request fails', () => {
        it('shows alert with error and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('Request failed'));

          deleteFlow();

          await waitForPromises();
          expect(findErrorsAlert().props('errors')).toStrictEqual([
            'Failed to remove flow. Error: Request failed',
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
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', () => {
      findAiCatalogList().vm.$emit('next-page');
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });
});

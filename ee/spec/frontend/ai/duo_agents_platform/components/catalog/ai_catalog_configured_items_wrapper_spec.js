import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockBaseFlow,
  mockBaseItemConsumer,
  mockConfiguredFlowsResponse,
  mockConfiguredItemsEmptyResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogConfiguredItemsWrapper', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockConfiguredFlowsQueryHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const defaultProvide = {
    projectId: mockProjectId,
  };

  const defaultProps = {
    emptyStateTitle: 'Use flows in your project.',
    emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
    emptyStateButtonHref: '/explore/ai-catalog/flows',
    emptyStateButtonText: 'Explore AI Catalog flows',
    itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
    itemTypeConfig: {
      showRoute: 'flows.show',
      visibilityTooltip: {
        public: 'Public flows',
        private: 'Private flows',
      },
    },
  };

  const createComponent = ({ provide = {}, props = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredFlowsQueryHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogConfiguredItemsWrapper, {
      apolloProvider: mockApollo,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $toast: mockToast,
      },
    });
  };

  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
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
        mockConfiguredFlowsQueryHandler.mockResolvedValueOnce(mockConfiguredItemsEmptyResponse);

        await waitForPromises();
      });

      it('renders empty state with correct props for project', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Use flows in your project.',
          description: 'Flows use multiple agents to complete tasks automatically.',
        });
      });

      it('renders empty state with correct props for group', async () => {
        const mockGroupId = 2;
        mockConfiguredFlowsQueryHandler.mockResolvedValueOnce(mockConfiguredItemsEmptyResponse);

        createComponent({
          provide: {
            projectId: null,
            groupId: mockGroupId,
          },
          props: {
            emptyStateTitle: 'Use flows in your group.',
          },
        });

        await waitForPromises();

        expect(findEmptyState().props()).toMatchObject({
          title: 'Use flows in your group.',
          description: 'Flows use multiple agents to complete tasks automatically.',
        });
      });
    });
  });

  describe('Apollo queries', () => {
    describe('when in project namespace', () => {
      beforeEach(() => {
        createComponent();
      });

      it('fetches list data with projectId', () => {
        expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          projectId: `gid://gitlab/Project/${mockProjectId}`,
          includeInherited: false,
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('when in group namespace', () => {
      const mockGroupId = 2;

      beforeEach(() => {
        createComponent({
          provide: {
            groupId: mockGroupId,
            projectId: null,
          },
        });
      });

      it('fetches list data with groupId', () => {
        expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          groupId: `gid://gitlab/Group/${mockGroupId}`,
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('disabling a flow', () => {
      const item = {
        ...mockBaseFlow,
        itemConsumer: mockBaseItemConsumer,
      };
      const disableFlow = () => findAiCatalogList().props('disableFn')(item);

      beforeEach(() => {
        createComponent();
      });

      it('calls delete consumer mutation', () => {
        disableFlow();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: mockBaseItemConsumer.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows a toast message and refetches the list', async () => {
          disableFlow();

          await waitForPromises();

          expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledTimes(2);
          expect(mockToast.show).toHaveBeenCalledWith('Flow disabled in this project.');
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('does not show toast and emits error', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );

          disableFlow();

          await waitForPromises();
          expect(wrapper.emitted('error')).toEqual([
            [
              {
                title: 'Failed to disable flow',
                errors: ['You do not have permission to disable this item.'],
              },
            ],
          ]);
          expect(mockToast.show).not.toHaveBeenCalled();
        });
      });

      describe('when request fails', () => {
        it('emits error event with title and errors, and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('Request failed'));

          disableFlow();

          await waitForPromises();
          expect(wrapper.emitted('error')).toEqual([
            [
              {
                title: 'Failed to disable flow',
                errors: ['Request failed'],
              },
            ],
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
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeInherited: false,
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', async () => {
      findAiCatalogList().vm.$emit('next-page');
      await nextTick();
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
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

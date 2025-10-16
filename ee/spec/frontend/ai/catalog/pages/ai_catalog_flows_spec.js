import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { isLoggedIn } from '~/lib/utils/common_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import {
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import {
  mockFlow,
  mockCatalogFlowsResponse,
  mockCatalogFlowDeleteResponse,
  mockCatalogFlowDeleteErrorResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockFlows,
  mockPageInfo,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils');

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

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);
  const deleteCatalogItemMutationHandler = jest.fn();
  const createAiCatalogItemConsumerHandler = jest.fn();

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ provide = {} } = {}) => {
    isLoggedIn.mockReturnValue(true);

    mockApollo = createMockApollo([
      [aiCatalogFlowsQuery, mockCatalogItemsQueryHandler],
      [deleteAiCatalogFlowMutation, deleteCatalogItemMutationHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogFlows, {
      apolloProvider: mockApollo,
      provide: {
        glFeatures: {
          aiCatalogFlows: true,
          aiCatalogThirdPartyFlows: true,
        },
        ...provide,
      },
      mocks: {
        $toast: mockToast,
        $router: mockRouter,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findAiCatalogItemConsumerModal = () => wrapper.findComponent(AiCatalogItemConsumerModal);

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

    it('renders filter search', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });
  });

  describe('Apollo queries', () => {
    describe('when both aiCatalogFlows and aiCatalogThirdPartyFlows are enabled', () => {
      beforeEach(() => {
        createComponent();
      });

      it('fetches list data with itemTypes', () => {
        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          after: null,
          before: null,
          first: 20,
          last: null,
          search: '',
        });
      });
    });

    describe('when only aiCatalogThirdPartyFlows is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              aiCatalogFlows: false,
              aiCatalogThirdPartyFlows: true,
            },
          },
        });
      });

      it('fetches list data with itemType THIRD_PARTY_FLOW', () => {
        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
          itemType: 'THIRD_PARTY_FLOW',
          after: null,
          before: null,
          first: 20,
          last: null,
          search: '',
        });
      });
    });

    describe('when only aiCatalogFlows is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              aiCatalogFlows: true,
              aiCatalogThirdPartyFlows: false,
            },
          },
        });
      });

      it('fetches list data with itemType FLOW', () => {
        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
          itemType: 'FLOW',
          after: null,
          before: null,
          first: 20,
          last: null,
          search: '',
        });
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
        expect(mockToast.show).toHaveBeenCalledWith('Flow deleted.');
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
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
        search: '',
      });
    });

    it('refetches query with correct variables when paging forward', () => {
      findAiCatalogList().vm.$emit('next-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
        search: '',
      });
    });
  });

  describe('search', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes search param to agents query on search', async () => {
      findFilteredSearch().vm.$emit('submit', ['foo']);
      await waitForPromises();

      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        after: null,
        before: null,
        first: 20,
        last: null,
        search: 'foo',
      });
    });
  });

  describe('on adding a flow to project', () => {
    const openModal = async () => {
      const firstItemAction = findAiCatalogList()
        .props('itemTypeConfig')
        .actionItems(mockFlows[0])[0];
      // We pass the function down to child components. Because we use shallowMount
      // we cannot trigger the action which would call the function. So we call it
      // using the properties.
      firstItemAction.action();
      await nextTick();
    };

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
        const createConsumer = () => findAiCatalogItemConsumerModal().vm.$emit('submit');

        describe('when adding to project request succeeds', () => {
          it('shows a toast message', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateSuccessProjectResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(mockToast.show).toHaveBeenCalledWith('Flow enabled in Test.');
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
              `Could not enable flow: ${mockFlow.name}`,
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
              'Could not enable flow in the project. Try again. Error: Request failed',
            ]);
            expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          });
        });
      });
    });
  });

  describe('tracking events', () => {
    describe('when component is mounted', () => {
      beforeEach(() => {
        createComponent();
      });

      it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX} event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
          { label: TRACK_EVENT_TYPE_FLOW },
          undefined,
        );
      });
    });
  });
});

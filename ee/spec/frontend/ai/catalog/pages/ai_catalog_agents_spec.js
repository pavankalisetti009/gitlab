import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import {
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
} from 'ee/ai/catalog/constants';
import {
  mockProjectWithNamespace,
  mockAgent,
  mockAgents,
  mockCatalogItemsResponse,
  mockCatalogAgentDeleteResponse,
  mockCatalogAgentDeleteErrorResponse,
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

  const mockRouter = {
    push: jest.fn(),
  };

  const mockToast = {
    show: jest.fn(),
  };

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const createAiCatalogItemConsumerHandler = jest.fn();
  const deleteCatalogItemMutationHandler = jest.fn();

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => {
    isLoggedIn.mockReturnValue(true);

    mockApollo = createMockApollo([
      [aiCatalogAgentsQuery, mockCatalogItemsQueryHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
      [deleteAiCatalogAgentMutation, deleteCatalogItemMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgents, {
      apolloProvider: mockApollo,
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

    it('renders filter search', () => {
      expect(findFilteredSearch().exists()).toBe(true);
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

    it('passes search param to agents query on search', async () => {
      findFilteredSearch().vm.$emit('submit', ['foo']);
      await waitForPromises();

      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: null,
        first: 20,
        last: null,
        search: 'foo',
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
        const createConsumer = () =>
          findAiCatalogItemConsumerModal().vm.$emit('submit', {
            projectId: mockProjectWithNamespace.id,
          });

        describe('when adding to project request succeeds', () => {
          it('shows a toast message', async () => {
            createAiCatalogItemConsumerHandler.mockResolvedValue(
              mockAiCatalogItemConsumerCreateSuccessProjectResponse,
            );

            createConsumer();
            await waitForPromises();

            expect(mockToast.show).toHaveBeenCalledWith('Agent enabled in Test.');
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
              `Could not enable agent: ${mockAgent.name}`,
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
              'Could not enable agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
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
        expect(mockToast.show).toHaveBeenCalledWith('Agent deleted.');
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
        search: '',
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
        search: '',
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
          { label: TRACK_EVENT_TYPE_AGENT },
          undefined,
        );
      });
    });
  });
});

import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import {
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
} from 'ee/ai/catalog/constants';
import { mockAgents, mockCatalogItemsResponse, mockPageInfo } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils');

Vue.use(VueApollo);

describe('AiCatalogAgents', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
    replace: jest.fn(),
  };

  const mockRoute = {
    query: {},
  };

  const mockToast = {
    show: jest.fn(),
  };

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ provide, routeQuery = {} } = {}) => {
    isLoggedIn.mockReturnValue(true);

    mockApollo = createMockApollo([[aiCatalogAgentsQuery, mockCatalogItemsQueryHandler]]);
    mockRoute.query = routeQuery;

    wrapper = shallowMountExtended(AiCatalogAgents, {
      apolloProvider: mockApollo,
      mocks: {
        $toast: mockToast,
        $router: mockRouter,
        $route: mockRoute,
      },
      provide: {
        glFeatures: {
          aiCatalogThirdPartyFlows: true,
        },
        ...provide,
      },
    });
  };

  const findAiCatalogListWrapper = () => wrapper.findComponent(AiCatalogListWrapper);

  describe('component rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('renders AiCatalogListWrapper component', () => {
      const catalogListWrapper = findAiCatalogListWrapper();

      expect(catalogListWrapper.exists()).toBe(true);
    });

    it('passes correct props to AiCatalogListWrapper', async () => {
      const catalogListWrapper = findAiCatalogListWrapper();
      await waitForPromises();

      expect(catalogListWrapper.props('items')).toEqual(mockAgents);
      expect(catalogListWrapper.props('isLoading')).toBe(false);
    });
  });

  describe('when loading', () => {
    it('passes loading state with boolean true to AiCatalogListWrapper', () => {
      createComponent();
      const catalogListWrapper = findAiCatalogListWrapper();

      expect(catalogListWrapper.props('isLoading')).toBe(true);
    });
  });

  describe('with agent data', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('fetches list data', () => {
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalled();
    });

    it('passes agent data to AiCatalogListWrapper', () => {
      const catalogListWrapper = findAiCatalogListWrapper();

      expect(catalogListWrapper.props('items')).toEqual(mockAgents);
      expect(catalogListWrapper.props('items')).toHaveLength(3);
    });

    it('passes isLoading as false when not loading', () => {
      const catalogListWrapper = findAiCatalogListWrapper();

      expect(catalogListWrapper.props('isLoading')).toBe(false);
    });
  });

  describe('when the feature flag for third party flows is off', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          glFeatures: { aiCatalogThirdPartyFlows: false },
        },
      });
    });

    it('fetches list data without third party flows', () => {
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT'],
        after: null,
        before: null,
        first: 20,
        last: null,
        search: '',
      });
    });
  });

  describe('pagination', () => {
    it('passes pageInfo to list component', async () => {
      createComponent();
      await waitForPromises();

      expect(findAiCatalogListWrapper().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging backward', async () => {
      createComponent();
      await waitForPromises();

      findAiCatalogListWrapper().vm.$emit('prev-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'],
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

      findAiCatalogListWrapper().vm.$emit('next-page');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'],
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
        search: '',
      });
    });
  });

  describe('search', () => {
    describe('default', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('passes search param to agents query on search', async () => {
        findAiCatalogListWrapper().vm.$emit('search', ['foo']);
        await waitForPromises();

        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'],
          after: null,
          before: null,
          first: 20,
          last: null,
          search: 'foo',
        });
      });

      it('updates URL query param when searching', async () => {
        findAiCatalogListWrapper().vm.$emit('search', ['foo']);
        await waitForPromises();

        expect(mockRouter.replace).toHaveBeenCalledWith({
          query: { search: 'foo' },
        });
      });

      it('clears search param when clear-search is emitted', async () => {
        // First set a search term
        findAiCatalogListWrapper().vm.$emit('search', ['foo']);
        await waitForPromises();

        // Then clear it
        findAiCatalogListWrapper().vm.$emit('clear-search');
        await waitForPromises();

        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'],
          after: null,
          before: null,
          first: 20,
          last: null,
          search: '',
        });
      });

      it('removes search param from URL when clearing search', async () => {
        mockRoute.query = { search: 'foo' };
        findAiCatalogListWrapper().vm.$emit('clear-search');
        await waitForPromises();

        expect(mockRouter.replace).toHaveBeenCalledWith({
          query: {},
        });
      });
    });

    it('initializes search term from URL query param', async () => {
      await createComponent({ routeQuery: { search: 'initial' } });
      await waitForPromises();

      expect(findAiCatalogListWrapper().props('searchTerm')).toBe('initial');
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'initial' }),
      );
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

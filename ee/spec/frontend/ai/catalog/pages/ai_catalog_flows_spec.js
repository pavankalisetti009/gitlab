import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';
import {
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import { mockCatalogFlowsResponse, mockFlows, mockPageInfo } from '../mock_data';

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

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ provide = {} } = {}) => {
    isLoggedIn.mockReturnValue(true);

    mockApollo = createMockApollo([[aiCatalogFlowsQuery, mockCatalogItemsQueryHandler]]);

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

  const findAiCatalogListWrapper = () => wrapper.findComponent(AiCatalogListWrapper);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('passes correct props to AiCatalogListWrapper', async () => {
      const catalogList = findAiCatalogListWrapper();

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

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to list component', () => {
      expect(findAiCatalogListWrapper().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging backward', () => {
      findAiCatalogListWrapper().vm.$emit('prev-page');
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
      findAiCatalogListWrapper().vm.$emit('next-page');
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
      await createComponent();
    });

    it('passes search param to agents query on search', async () => {
      findAiCatalogListWrapper().vm.$emit('search', ['foo']);
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

    it('clears search param when clear-search is emitted', async () => {
      // First set a search term
      findAiCatalogListWrapper().vm.$emit('search', ['foo']);
      await waitForPromises();

      // Then clear it
      findAiCatalogListWrapper().vm.$emit('clear-search');
      await waitForPromises();

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

import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
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

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

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

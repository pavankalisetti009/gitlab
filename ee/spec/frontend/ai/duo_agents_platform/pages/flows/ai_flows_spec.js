import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiFlows from 'ee/ai/duo_agents_platform/pages/flows/ai_flows.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import {
  mockAiCatalogFlowResponse,
  mockBaseFlow,
  mockConfiguredFlowsResponse,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';

Vue.use(VueApollo);

describe('AiFlows', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };
  const mockProjectId = 1;
  const mockConfiguredFlowsQueryHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);
  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);

  const createComponent = ({ $route = { query: {} } } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredFlowsQueryHandler],
      [aiCatalogFlowQuery, mockFlowQueryHandler],
    ]);

    wrapper = shallowMountExtended(AiFlows, {
      apolloProvider: mockApollo,
      provide: {
        projectId: mockProjectId,
      },
      mocks: {
        $router: mockRouter,
        $route,
      },
    });
  };

  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

  beforeEach(() => {
    createComponent();
  });
  describe('component rendering', () => {
    it('renders PageHeading component', () => {
      expect(wrapper.findComponent(PageHeading).exists()).toBe(true);
    });

    it('renders AiCatalogList component', async () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual([mockBaseFlow]);
      expect(catalogList.props('isLoading')).toBe(false);
    });
  });

  describe('Apollo queries', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches list data', () => {
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        after: null,
        before: null,
        first: 20,
        last: null,
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

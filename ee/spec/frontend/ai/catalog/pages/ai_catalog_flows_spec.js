import VueApollo from 'vue-apollo';
import Vue from 'vue';

import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';

import { mockCatalogFlowsResponse, mockFlows } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogFlows', () => {
  let wrapper;
  let mockApollo;

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([[aiCatalogFlowsQuery, mockCatalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogFlows, {
      apolloProvider: mockApollo,
    });

    return waitForPromises();
  };

  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

  describe('component rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders AiCatalogList component', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.exists()).toBe(true);
    });

    it('passes correct props to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('items')).toEqual(mockFlows);
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

  describe('with flow data', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('fetches list data', () => {
      expect(mockCatalogItemsQueryHandler).toHaveBeenCalled();
    });

    it('passes flow data to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('items')).toEqual(mockFlows);
      expect(catalogList.props('items')).toHaveLength(3);
    });

    it('passes isLoading as false when not loading', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(false);
    });
  });
});

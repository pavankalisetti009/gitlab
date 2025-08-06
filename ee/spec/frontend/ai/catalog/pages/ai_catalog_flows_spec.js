import VueApollo from 'vue-apollo';
import Vue from 'vue';

import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';

import {
  mockFlow,
  mockAiCatalogFlowResponse,
  mockCatalogFlowsResponse,
  mockFlows,
} from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogFlows', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };

  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);

  const createComponent = ({ $route = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [aiCatalogFlowsQuery, mockCatalogItemsQueryHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogFlows, {
      apolloProvider: mockApollo,
      mocks: {
        $router: mockRouter,
        $route,
      },
    });
  };

  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findAiCatalogItemDrawer = () => wrapper.findComponent(AiCatalogItemDrawer);

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

  describe('when linking directly to a flow via URL', () => {
    describe('when item id is found in list', () => {
      beforeEach(async () => {
        await createComponent({ $route: { query: { show: '4' } } });
      });

      it('fetches full flow details', () => {
        expect(mockFlowQueryHandler).toHaveBeenCalledTimes(1);
        expect(mockFlowQueryHandler).toHaveBeenCalledWith({
          id: mockFlows[0].id,
        });
      });

      it('opens the drawer and passes found activeItem while loading', () => {
        expect(findAiCatalogItemDrawer().props()).toMatchObject({
          isOpen: true,
          isItemDetailsLoading: true,
          activeItem: mockFlows[0],
        });
      });

      it('passes full details to drawer when loading is complete', async () => {
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

        it('closes the drawer on drawer `close` event', () => {
          expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
        });

        it('updates router', () => {
          expect(mockRouter.push.mock.calls[0][0].query.show).toBeUndefined();
        });
      });
    });

    describe('when item id is not found in list', () => {
      beforeEach(async () => {
        await createComponent({ $route: { query: { show: '100' } } });
      });

      it('does not fetch full flow details', () => {
        expect(mockFlowQueryHandler).not.toHaveBeenCalled();
      });

      it('does not open the drawer', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });
    });
  });
});

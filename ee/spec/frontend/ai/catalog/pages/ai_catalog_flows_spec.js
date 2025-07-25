import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';

import { updateHistory, removeParams } from '~/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import AiCatalogFlows from 'ee/ai/catalog/pages/ai_catalog_flows.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogFlowsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flows.query.graphql';
import { AI_CATALOG_SHOW_QUERY_PARAM } from 'ee/ai/catalog/router/constants';

import { mockCatalogFlowsResponse, mockFlows } from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => {
  return {
    ...jest.requireActual('~/lib/utils/url_utility'),
    removeParams: jest.fn(),
    updateHistory: jest.fn(),
  };
});

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

  describe('on selecting a flow', () => {
    beforeEach(async () => {
      await createComponent();

      findAiCatalogList().vm.$emit('select-item', mockFlows[0]);
      return nextTick();
    });

    it('opens item drawer', () => {
      expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
    });

    it('selects active item', () => {
      expect(findAiCatalogItemDrawer().props('activeItem')).toEqual(mockFlows[0]);
    });

    describe('when closing the drawer', () => {
      beforeEach(() => {
        findAiCatalogItemDrawer().vm.$emit('close');
      });

      it('closes the drawer on drawer `close` event', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
      });

      it('removes active agent and updates URL', () => {
        expect(findAiCatalogItemDrawer().props('activeItem')).toBe(null);

        expect(updateHistory).toHaveBeenCalled();
        expect(removeParams).toHaveBeenCalledWith([AI_CATALOG_SHOW_QUERY_PARAM]);
      });
    });
  });

  describe('when linking directly to a flow via URL', () => {
    describe('when item id is found in list', () => {
      beforeEach(async () => {
        setWindowLocation('?show=4');
        await createComponent();
      });

      it('opens the drawer and passes activeItem as prop', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
        expect(findAiCatalogItemDrawer().props('activeItem')).toEqual(mockFlows[0]);
      });
    });

    describe('when item id is not found in list', () => {
      beforeEach(async () => {
        setWindowLocation('?show=98');
        await createComponent();
      });

      it('does not open the drawer', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
        expect(findAiCatalogItemDrawer().props('activeItem')).toBeNull();
      });
    });
  });
});

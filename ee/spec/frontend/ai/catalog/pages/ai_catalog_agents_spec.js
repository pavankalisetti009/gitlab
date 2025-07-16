import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';

import { updateHistory, removeParams } from '~/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import { AI_CATALOG_SHOW_QUERY_PARAM } from 'ee/ai/catalog/router/constants';

import { mockCatalogItemsResponse, mockAgents } from '../mock_data';

jest.mock('~/lib/utils/url_utility');

Vue.use(VueApollo);

describe('AiCatalogAgents', () => {
  let wrapper;
  let mockApollo;

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([[aiCatalogAgentsQuery, mockCatalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogAgents, {
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

      expect(catalogList.props('items')).toEqual(mockAgents);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    it('renders item drawer closed by default', () => {
      expect(findAiCatalogItemDrawer().exists()).toBe(true);
      expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
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
  });

  describe('on selecting an agent', () => {
    beforeEach(async () => {
      await createComponent();

      findAiCatalogList().vm.$emit('select-item', mockAgents[0]);
      return nextTick();
    });

    it('opens issuable drawer', () => {
      expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
    });

    it('selects active issuable', () => {
      expect(findAiCatalogItemDrawer().props('activeItem')).toEqual(mockAgents[0]);
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
});

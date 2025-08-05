import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlAlert } from '@gitlab/ui';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import AiCatalogAgents from 'ee/ai/catalog/pages/ai_catalog_agents.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import {
  mockAgents,
  mockCatalogItemsResponse,
  mockCatalogItemDeleteResponse,
  mockCatalogItemDeleteErrorResponse,
} from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => {
  return {
    ...jest.requireActual('~/lib/utils/url_utility'),
    removeParams: jest.fn(),
    updateHistory: jest.fn(),
  };
});
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogAgents', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };

  const mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const deleteCatalogItemMutationHandler = jest.fn();
  const mockToast = {
    show: jest.fn(),
  };

  const createComponent = ({ $route = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogAgentsQuery, mockCatalogItemsQueryHandler],
      [deleteAiCatalogAgentMutation, deleteCatalogItemMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgents, {
      apolloProvider: mockApollo,
      mocks: {
        $toast: mockToast,
        $router: mockRouter,
        $route,
      },
    });

    return waitForPromises();
  };

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);
  const findAiCatalogItemDrawer = () => wrapper.findComponent(AiCatalogItemDrawer);

  afterEach(() => {
    jest.clearAllMocks();
  });

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

  describe('when linking directly to an agent via URL', () => {
    describe('when item id is found in list', () => {
      beforeEach(async () => {
        await createComponent({ $route: { query: { show: '1' } } });
      });

      it('opens the drawer and passes activeItem as prop', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(true);
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

          expect(mockRouter.push.mock.calls[0][0].query.show).toBeUndefined();
        });
      });
    });

    describe('when item id is not found in list', () => {
      beforeEach(async () => {
        await createComponent({ $route: { query: { show: '100' } } });
      });

      it('does not open the drawer', () => {
        expect(findAiCatalogItemDrawer().props('isOpen')).toBe(false);
        expect(findAiCatalogItemDrawer().props('activeItem')).toBeNull();
      });
    });
  });

  describe('on deleting an agent', () => {
    const deleteAgent = (index = 0) => findAiCatalogList().props('deleteFn')(mockAgents[index].id);

    beforeEach(() => {
      createComponent();
    });

    it('calls delete mutation', () => {
      deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogItemDeleteResponse);

      deleteAgent();

      expect(deleteCatalogItemMutationHandler).toHaveBeenCalledWith({ id: mockAgents[0].id });
    });

    describe('when request succeeds', () => {
      it('shows a toast message and refetches the list', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogItemDeleteResponse);

        deleteAgent();

        await waitForPromises();

        expect(mockCatalogItemsQueryHandler).toHaveBeenCalledTimes(2);
        expect(mockToast.show).toHaveBeenCalledWith('Agent deleted successfully.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows alert with error', async () => {
        deleteCatalogItemMutationHandler.mockResolvedValue(mockCatalogItemDeleteErrorResponse);

        deleteAgent();

        await waitForPromises();
        expect(findGlAlert().text()).toBe(
          'Failed to delete agent. You do not have permission to delete this AI agent.',
        );
      });
    });

    describe('when request fails', () => {
      it('shows alert with error and captures exception', async () => {
        deleteCatalogItemMutationHandler.mockRejectedValue(new Error('Request failed'));

        deleteAgent();

        await waitForPromises();
        expect(findGlAlert().text()).toBe('Failed to delete agent. Error: Request failed');
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});

import { shallowMount } from '@vue/test-utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import { AI_CATALOG_AGENTS_ROUTE } from 'ee/ai/catalog/router/constants';

jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

describe('AiCatalogAgentsShow', () => {
  let wrapper;
  let mockApolloClient;
  let mockRouter;
  const agentId = 732;

  const mockAgent = {
    id: agentId,
    name: 'Claude Sonnet 4',
    description: 'Smart, efficient model for everyday user',
    model: 'claude-sonnet-4-20250514',
  };

  beforeEach(() => {
    mockApolloClient = {
      cache: {
        readQuery: jest.fn(),
      },
    };

    mockRouter = {
      push: jest.fn(),
    };

    jest.clearAllMocks();
  });

  const createComponent = (routeParams = { id: agentId }, apolloData = mockAgent) => {
    wrapper = shallowMount(AiCatalogAgentsShow, {
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: mockRouter,
        $apollo: {
          provider: {
            clients: {
              defaultClient: mockApolloClient,
            },
          },
        },
      },
      data() {
        return {
          aiCatalogAgent: apolloData,
        };
      },
    });
  };

  const findHeader = () => wrapper.findComponent(PageHeading);

  describe('component rendering', () => {
    it('renders the page heading with the agent name', async () => {
      await createComponent();

      expect(findHeader().props('heading')).toBe(`Edit agent: ${mockAgent.name}`);
    });
  });

  describe('beforeRouteEnter hook', () => {
    const invalidId = '1';

    let component;
    let mockNext;
    let mockVm;

    beforeEach(() => {
      component = AiCatalogAgentsShow;
      mockNext = jest.fn();
      mockVm = {
        $apollo: {
          provider: {
            clients: {
              defaultClient: mockApolloClient,
            },
          },
        },
        $router: mockRouter,
      };
    });

    it('redirects when agent is not found in cache', () => {
      const to = { params: { id: invalidId } };
      mockApolloClient.cache.readQuery.mockReturnValue({
        aiCatalogAgent: null,
      });

      component.beforeRouteEnter(to, {}, mockNext);

      const callback = mockNext.mock.calls[0][0];
      callback(mockVm);

      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
    });

    it('redirects when the id is not a number', () => {
      const to = { params: { id: 'invalidId' } };

      component.beforeRouteEnter(to, {}, mockNext);

      expect(mockNext).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
    });

    it('calls Sentry when cache query fails', () => {
      const to = { params: { id: invalidId } };
      const cacheError = new Error('Cache read failed');
      mockApolloClient.cache.readQuery.mockImplementation(() => {
        throw cacheError;
      });

      component.beforeRouteEnter(to, {}, mockNext);

      const callback = mockNext.mock.calls[0][0];
      callback(mockVm);

      expect(Sentry.captureException).toHaveBeenCalledWith(
        expect.objectContaining({
          message: `Agent not found: Failed to query agent with ID ${invalidId}`,
          cause: cacheError,
        }),
      );
      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
    });
  });
});

import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformBreadcrumbs from 'ee/ai/duo_agents_platform/router/duo_agents_platform_breadcrumbs.vue';
import {
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTS_PLATFORM_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';

describe('DuoAgentsPlatformBreadcrumbs', () => {
  let wrapper;

  const defaultProps = {
    staticBreadcrumbs: [
      {
        text: 'Test Group',
        to: '/groups/test-group',
      },
      {
        text: 'Test Project',
        to: '/test-group/test-project',
      },
    ],
  };

  const createWrapper = (routeOptions = { matched: [], params: {} }) => {
    wrapper = shallowMount(DuoAgentsPlatformBreadcrumbs, {
      propsData: {
        ...defaultProps,
      },
      mocks: {
        $route: {
          path: '/agent-sessions',
          matched: routeOptions.matched,
          params: {
            ...routeOptions.params,
          },
        },
      },
      stubs: {
        GlBreadcrumb,
      },
    });
  };

  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);
  const getBreadcrumbItems = () => findBreadcrumb().props('items');

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the breadcrumb component', () => {
      expect(findBreadcrumb().exists()).toBe(true);
    });

    it('passes auto-resize as false to breadcrumb', () => {
      expect(findBreadcrumb().props('autoResize')).toBe(false);
    });
  });

  describe.each`
    expectedText        | path                               | matched                                                                                                                                                                 | params
    ${'Agent sessions'} | ${'/agent-sessions'}               | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }]}                                                                                                      | ${{}}
    ${'New'}            | ${'/agent-sessions/new'}           | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }, { path: '/agent-sessions/new', name: AGENTS_PLATFORM_NEW_ROUTE, meta: { text: 'New' }, parent: {} }]} | ${{}}
    ${'4'}              | ${'/agent-sessions/4'}             | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }, { path: '/agent-sessions/:id', name: AGENTS_PLATFORM_SHOW_ROUTE, parent: {} }]}                       | ${{ id: 4 }}
    ${'Agent sessions'} | ${'/unknown-scope/agent-sessions'} | ${[{ path: '/unknown-scope/agent-sessions', meta: { text: 'Agent sessions' } }]}                                                                                        | ${{}}
  `('breadcrumbs generation', ({ expectedText, matched, path, params }) => {
    beforeEach(() => {
      createWrapper({
        matched,
        params,
      });
    });

    it(`displays the correct number of breadcrumb items for ${path}`, () => {
      const items = getBreadcrumbItems();
      // static routes + Automate + Agent Sessions + dynamic routes
      const totalLength = 3 + matched.length;

      expect(items).toHaveLength(totalLength);
      expect(items[totalLength - 1].text).toBe(expectedText);
    });
  });

  describe('when matched route has a parent', () => {
    it('returns a to object with name', () => {
      createWrapper({
        matched: [
          { path: '/agent-sessions', meta: { text: 'Agent sessions' } },
          {
            path: '/agent-sessions/new',
            name: AGENTS_PLATFORM_NEW_ROUTE,
            meta: { text: 'New' },
            parent: {},
          },
        ],
        params: {},
      });

      const items = getBreadcrumbItems();
      const newRouteItem = items.find((item) => item.text === 'New');

      expect(newRouteItem.to).toEqual({ name: AGENTS_PLATFORM_NEW_ROUTE });
    });
  });

  describe('when matched route does not have a parent', () => {
    it('returns a to object with path', () => {
      createWrapper({
        matched: [{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }],
        params: {},
      });

      const items = getBreadcrumbItems();
      const agentSessionsItem = items.find((item) => item.text === 'Agent sessions');

      expect(agentSessionsItem.to).toEqual({ path: '/agent-sessions' });
    });
  });
});

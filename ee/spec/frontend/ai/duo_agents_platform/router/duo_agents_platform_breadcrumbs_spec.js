import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformBreadcrumbs from 'ee/ai/duo_agents_platform/router/duo_agents_platform_breadcrumbs.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
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
          name: AGENTS_PLATFORM_INDEX_ROUTE,
          path: '/agent-sessions',
          matched: [],
          params: {},
          ...routeOptions,
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
    routeName                      | expectedText        | path                               | matched                                                                                                                    | params
    ${AGENTS_PLATFORM_INDEX_ROUTE} | ${'Agent sessions'} | ${'/agent-sessions'}               | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }]}                                                         | ${{}}
    ${AGENTS_PLATFORM_NEW_ROUTE}   | ${'New'}            | ${'/agent-sessions/new'}           | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }, { path: '/agent-sessions/new', meta: { text: 'New' } }]} | ${{}}
    ${AGENTS_PLATFORM_SHOW_ROUTE}  | ${'4'}              | ${'/agent-sessions/4'}             | ${[{ path: '/agent-sessions', meta: { text: 'Agent sessions' } }, { path: '/agent-sessions/:id' }]}                        | ${{ id: 4 }}
    ${AGENTS_PLATFORM_INDEX_ROUTE} | ${'Agent sessions'} | ${'/unknown-scope/agent-sessions'} | ${[{ path: '/unknown-scope/agent-sessions', meta: { text: 'Agent sessions' } }]}                                           | ${{}}
  `('breadcrumbs generation', ({ expectedText, matched, routeName, path, params }) => {
    beforeEach(() => {
      createWrapper({
        name: routeName,
        matched,
        params,
      });
    });

    it(`displays the correct number of breadcrumb items for ${path}`, () => {
      const items = getBreadcrumbItems();
      // 2 static routes + Automate + Agent Sessions + dynamic routes
      const totalLength = 3 + matched.length;

      expect(items).toHaveLength(totalLength);
      expect(items[totalLength - 1].text).toBe(expectedText);
    });
  });
});

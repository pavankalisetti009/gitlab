import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AiCatalogBreadcrumbs from 'ee/ai/catalog/router/ai_catalog_breadcrumbs.vue';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
} from 'ee/ai/catalog/router/constants';

describe('AiCatalogBreadcrumbs', () => {
  let wrapper;

  const mockExploreBreadcrumb = {
    text: 'Explore',
    to: '/explore',
  };
  const defaultProps = {
    staticBreadcrumbs: [mockExploreBreadcrumb],
  };

  const createComponent = (routeOptions = { matched: [], params: {} }) => {
    wrapper = shallowMount(AiCatalogBreadcrumbs, {
      propsData: {
        ...defaultProps,
      },
      mocks: {
        $route: {
          name: AI_CATALOG_INDEX_ROUTE,
          path: '/ai-catalog',
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

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders breadcrumbs', () => {
      expect(findBreadcrumb().exists()).toBe(true);
      expect(findBreadcrumb().props('autoResize')).toBe(false);
    });
  });

  describe.each`
    routeName                       | expectedText    | matched                                                                                                        | params
    ${AI_CATALOG_INDEX_ROUTE}       | ${'AI Catalog'} | ${[]}                                                                                                          | ${{}}
    ${AI_CATALOG_AGENTS_ROUTE}      | ${'Agents'}     | ${[{ path: '/agents', meta: { text: 'Agents' } }]}                                                             | ${{}}
    ${AI_CATALOG_AGENTS_NEW_ROUTE}  | ${'New agent'}  | ${[{ path: '/agents', meta: { text: 'Agents' } }, { path: '/agents/new', meta: { text: 'New agent' } }]}       | ${{}}
    ${AI_CATALOG_AGENTS_EDIT_ROUTE} | ${'Edit agent'} | ${[{ path: '/agents', meta: { text: 'Agents' } }, { path: '/agents/:id/edit', meta: { text: 'Edit agent' } }]} | ${{ id: 4 }}
    ${AI_CATALOG_FLOWS_ROUTE}       | ${'Flows'}      | ${[{ path: '/flows', meta: { text: 'Flows' } }]}                                                               | ${{}}
  `('breadcrumbs on $routeName', ({ expectedText, matched, routeName, params }) => {
    beforeEach(() => {
      createComponent({
        name: routeName,
        matched,
        params,
      });
    });

    it('renders correct items', () => {
      const items = getBreadcrumbItems();
      // 1 static route + AI Catalog + dynamic routes
      const totalLength = 2 + matched.length;

      expect(items).toHaveLength(totalLength);
      expect(items[totalLength - 1].text).toBe(expectedText);
    });
  });
});

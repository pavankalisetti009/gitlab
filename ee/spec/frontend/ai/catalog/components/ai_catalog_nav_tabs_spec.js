import { GlTab, GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_FLOWS_ROUTE } from 'ee/ai/catalog/router/constants';

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({
    routeName = '/agents',
    routeQuery = {},
    aiCatalogFlows = true,
    readAiCatalogFlow = true,
  } = {}) => {
    wrapper = shallowMountExtended(AiCatalogNavTabs, {
      mocks: {
        $route: {
          name: routeName,
          path: routeName,
          query: routeQuery,
        },
        $router: mockRouter,
      },
      provide: {
        glAbilities: {
          readAiCatalogFlow,
        },
        glFeatures: {
          aiCatalogFlows,
        },
      },
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders tabs', () => {
      expect(findTabs().exists()).toBe(true);
    });

    it('renders the correct number of tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });

    it('renders the Agents tab as active', () => {
      const agentsTab = findAllTabs().at(0);

      expect(agentsTab.attributes('title')).toBe('Agents');
      expect(agentsTab.attributes('active')).toBe('true');
    });

    it('renders the Flows tab', () => {
      const flowsTab = findAllTabs().at(1);

      expect(flowsTab.attributes('title')).toBe('Flows');
    });
  });

  describe('when readAiCatalogFlow is null and aiCatalogFlows FF is false', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: null, aiCatalogFlows: false });
    });

    it('does not render the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(1);
      expect(findAllTabs().at(0).attributes('title')).toBe('Agents');
    });
  });

  describe('when readAiCatalogFlow is null and aiCatalogFlows FF is true', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: null, aiCatalogFlows: true });
    });

    it('renders the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(2);
      expect(findAllTabs().at(1).attributes('title')).toBe('Flows');
    });
  });

  describe('when readAiCatalogFlow is false and aiCatalogFlows FF is true', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: false, aiCatalogFlows: true });
    });

    it('does not render the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(1);
      expect(findAllTabs().at(0).attributes('title')).toBe('Agents');
    });
  });

  describe('when readAiCatalogFlow is true and aiCatalogFlows FF is false', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: true, aiCatalogFlows: false });
    });

    it('renders the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(2);
      expect(findAllTabs().at(1).attributes('title')).toBe('Flows');
    });
  });

  describe('when readAiCatalogFlow is false and aiCatalogFlows FF is false', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: false, aiCatalogFlows: false });
    });

    it('does not render the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(1);
      expect(findAllTabs().at(0).attributes('title')).toBe('Agents');
    });
  });

  describe('when readAiCatalogFlow is true and aiCatalogFlows FF is true', () => {
    beforeEach(() => {
      createComponent({ readAiCatalogFlow: true, aiCatalogFlows: true });
    });

    it('renders the Flows tab', () => {
      expect(findAllTabs()).toHaveLength(2);
      expect(findAllTabs().at(1).attributes('title')).toBe('Flows');
    });
  });

  describe('when on Flows route', () => {
    beforeEach(() => {
      createComponent({ routeName: AI_CATALOG_FLOWS_ROUTE });
    });

    it('renders the Flows tab as active', () => {
      const flowsTab = findAllTabs().at(1);

      expect(flowsTab.attributes('active')).toBe('true');
    });
  });

  describe('navigation', () => {
    it('navigates to the correct route when tab is clicked', () => {
      createComponent();

      const agentsTab = findAllTabs().at(1);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_FLOWS_ROUTE, query: {} });
    });

    it('preserves query params when navigating between tabs', () => {
      createComponent({ routePath: AI_CATALOG_AGENTS_ROUTE, routeQuery: { search: 'test' } });

      const flowsTab = findAllTabs().at(1);

      flowsTab.vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: AI_CATALOG_FLOWS_ROUTE,
        query: { search: 'test' },
      });
    });

    it('does not navigate if already on the same route', () => {
      createComponent({ routeName: AI_CATALOG_AGENTS_ROUTE });

      const agentsTab = findAllTabs().at(0);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).not.toHaveBeenCalled();
    });
  });
});

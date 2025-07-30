import { GlTab, GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_FLOWS_ROUTE } from 'ee/ai/catalog/router/constants';

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({ routePath = '/ai/catalog' } = {}) => {
    wrapper = shallowMountExtended(AiCatalogNavTabs, {
      mocks: {
        $route: {
          path: routePath,
        },
        $router: mockRouter,
      },
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);

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

  describe('when on Flows route', () => {
    beforeEach(() => {
      createComponent({ routePath: AI_CATALOG_FLOWS_ROUTE });
    });

    it('renders the Flows tab as active', () => {
      const flowsTab = findAllTabs().at(1);

      expect(flowsTab.attributes('active')).toBe('true');
    });
  });

  describe('navigation', () => {
    it('navigates to the correct route when tab is clicked', () => {
      const agentsTab = findAllTabs().at(0);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
    });

    it('does not navigate if already on the same route', () => {
      createComponent({ routePath: AI_CATALOG_AGENTS_ROUTE });

      const agentsTab = findAllTabs().at(0);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).not.toHaveBeenCalled();
    });
  });
});

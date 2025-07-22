import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
} from 'ee/ai/catalog/router/constants';

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const createComponent = ({ routePath = AI_CATALOG_AGENTS_ROUTE } = {}) => {
    wrapper = shallowMountExtended(AiCatalogNavActions, {
      mocks: {
        $route: {
          path: routePath,
        },
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  describe('when on the agents route', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders button', () => {
      expect(findButton().exists()).toBe(true);
    });

    it('passes correct route to button', () => {
      expect(findButton().props('to')).toEqual({ name: AI_CATALOG_AGENTS_NEW_ROUTE });
    });
  });

  describe('when on flows route', () => {
    beforeEach(() => {
      createComponent({ routePath: AI_CATALOG_FLOWS_ROUTE });
    });

    it('renders button', () => {
      expect(findButton().exists()).toBe(true);
    });

    it('passes correct route to button', () => {
      expect(findButton().props('to')).toEqual({ name: AI_CATALOG_FLOWS_NEW_ROUTE });
    });
  });

  describe('When on other route', () => {
    beforeEach(() => {
      createComponent({ routePath: AI_CATALOG_FLOWS_NEW_ROUTE });
    });

    it('does not render button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });
});

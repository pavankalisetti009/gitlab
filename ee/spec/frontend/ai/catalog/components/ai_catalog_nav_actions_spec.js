import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';

import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
} from 'ee/ai/catalog/router/constants';

jest.mock('~/lib/utils/common_utils');

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const createComponent = ({ routeName = AI_CATALOG_AGENTS_ROUTE } = {}) => {
    wrapper = shallowMountExtended(AiCatalogNavActions, {
      mocks: {
        $route: {
          name: routeName,
        },
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  describe('when on agents route', () => {
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
      createComponent({ routeName: AI_CATALOG_FLOWS_ROUTE });
    });

    it('renders button', () => {
      expect(findButton().exists()).toBe(true);
    });

    it('passes correct route to button', () => {
      expect(findButton().props('to')).toEqual({ name: AI_CATALOG_FLOWS_NEW_ROUTE });
    });
  });

  describe('when on other route', () => {
    beforeEach(() => {
      createComponent({ routeName: AI_CATALOG_FLOWS_NEW_ROUTE });
    });

    it('does not render button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('authentication state', () => {
    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);
    });

    describe('when user is authenticated', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(true);
        createComponent();
      });

      it('renders New agent button', () => {
        expect(findButton().exists()).toBe(true);
        expect(findButton().text()).toBe('New agent');
      });
    });

    describe('when user is not authenticated', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(false);
        createComponent();
      });

      it('does not render New agent button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user is authenticated on flows route', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(true);
        createComponent({ routeName: AI_CATALOG_FLOWS_ROUTE });
      });

      it('renders New flow button', () => {
        expect(findButton().exists()).toBe(true);
        expect(findButton().text()).toBe('New flow');
      });
    });

    describe('when user is not authenticated on flows route', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(false);
        createComponent({ routeName: AI_CATALOG_FLOWS_ROUTE });
      });

      it('does not render New flow button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });
});

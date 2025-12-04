import { GlExperimentBadge, GlLink, GlIcon, GlPopover, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import LinkToDashboardModal from 'ee/analytics/analytics_dashboards/link_to_dashboards/link_to_dashboards_modal.vue';
import {
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/tracking';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { DOCS_URL } from 'jh_else_ce/lib/utils/url_utility';

jest.mock('lodash/uniqueId', () => (x) => x);

describe('AiCatalogListHeader', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findDashboardLink = () => wrapper.findComponent(GlLink);
  const findDashboardIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPopoverLink = () => findPopover().findComponent(GlLink);
  const findLinkToDashboardModal = () => wrapper.findComponent(LinkToDashboardModal);
  const findNavTabs = () => wrapper.findComponent(AiCatalogNavTabs);
  const findNavActions = () => wrapper.findComponent(AiCatalogNavActions);

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListHeader, {
      propsData: {
        ...props,
      },
      provide: {
        isGlobal: true,
        canAdmin: false,
        aiImpactDashboardEnabled: true,
        ...provide,
      },
      directives: {
        GlModal: createMockDirective('gl-modal'),
      },
      stubs,
    });
  };

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders default title', () => {
      expect(findPageHeading().text()).toContain('AI Catalog');
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
    });

    it('renders AiCatalogNavTabs component', () => {
      expect(findNavTabs().exists()).toBe(true);
    });

    it('renders AiCatalogNavActions component', () => {
      expect(findNavActions().exists()).toBe(true);
    });
  });

  describe('dashboard link', () => {
    describe('when aiImpactDashboardEnabled is true', () => {
      beforeEach(() => {
        createComponent({ provide: { aiImpactDashboardEnabled: true }, stubs: { GlSprintf } });
      });

      it('renders link to dashboard with correct text', () => {
        expect(findDashboardLink().exists()).toBe(true);
        expect(findDashboardLink().text()).toBe('Explore your GitLab Duo and SDLC trends');
      });

      it('sets the modal directive correctly', () => {
        const linkModalDirective = getBinding(findDashboardLink().element, 'gl-modal');
        expect(linkModalDirective.value).toBe('link-to-dashboard-modal');
      });

      it('renders information icon', () => {
        expect(findDashboardIcon().exists()).toBe(true);
        expect(findDashboardIcon().props('name')).toBe('information-o');
      });

      it('has correct aria-label', () => {
        expect(findDashboardLink().attributes('aria-label')).toBe(
          'Explore your GitLab Duo and SDLC trends',
        );
      });

      it('has correct tracking attributes', () => {
        expect(findDashboardLink().attributes('data-track-action')).toBe(
          TRACKING_ACTION_CLICK_DASHBOARD_LINK,
        );
        expect(findDashboardLink().attributes('data-track-label')).toBe(
          TRACKING_LABEL_AI_CATALOG_HEADER,
        );
      });

      it('renders modal with correct dashboard name', () => {
        expect(findLinkToDashboardModal().exists()).toBe(true);
        expect(findLinkToDashboardModal().props('dashboardName')).toBe('duo_and_sdlc_trends');
      });

      it('renders the info popover', () => {
        expect(findDashboardIcon().attributes('id')).toBe('dashboard-link');
        expect(findPopover().props('target')).toBe('dashboard-link');
      });

      it('renders the popover content with link', () => {
        expect(findPopover().text()).toMatchInterpolatedText(
          'This key dashboard provides visibility into SDLC metrics in the context of AI adoption for projects and groups. Learn more',
        );
        expect(findPopoverLink().attributes('href')).toBe(
          `${DOCS_URL}/user/analytics/duo_and_sdlc_trends/`,
        );
      });
    });

    describe('when aiImpactDashboardEnabled is false', () => {
      beforeEach(() => {
        createComponent({ provide: { aiImpactDashboardEnabled: false } });
      });

      it('does not render link to dashboard', () => {
        expect(findDashboardLink().exists()).toBe(false);
      });

      it('does not render modal', () => {
        expect(findLinkToDashboardModal().exists()).toBe(false);
      });
    });
  });

  describe('when isGlobal is false', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isGlobal: false,
        },
      });
    });

    it('does not render AiCatalogNavTabs component', () => {
      expect(findNavTabs().exists()).toBe(false);
    });

    it('renders AiCatalogNavActions component in actions slot', () => {
      expect(findNavActions().exists()).toBe(true);
    });

    it('passes canAdmin prop to nav actions', () => {
      createComponent({
        provide: { isGlobal: false },
        props: { canAdmin: true },
      });

      expect(findNavActions().props('canAdmin')).toBe(true);
    });

    it('passes newButtonVariant prop to nav actions', () => {
      createComponent({
        provide: { isGlobal: false },
        props: { newButtonVariant: 'confirm' },
      });

      expect(findNavActions().props('newButtonVariant')).toBe('confirm');
    });

    it('renders slot content in nav actions', () => {
      wrapper = shallowMountExtended(AiCatalogListHeader, {
        propsData: {},
        provide: {
          isGlobal: false,
        },
        slots: {
          'nav-actions': '<div data-testid="custom-nav-content">Custom Content</div>',
        },
      });

      expect(wrapper.findByTestId('custom-nav-content').exists()).toBe(true);
    });
  });

  describe('when isGlobal is true', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isGlobal: true,
        },
      });
    });

    it('renders AiCatalogNavTabs component', () => {
      expect(findNavTabs().exists()).toBe(true);
    });

    it('renders AiCatalogNavActions component with canAdmin true', () => {
      const navActions = findNavActions();
      expect(navActions.exists()).toBe(true);
      expect(navActions.props('canAdmin')).toBe(true);
    });

    it('does not render nav actions in page heading actions slot', () => {
      // When isGlobal is true, nav actions are rendered in a separate div, not in the page heading actions
      const pageHeading = findPageHeading();
      expect(pageHeading.exists()).toBe(true);
    });
  });

  describe('when heading prop is passed', () => {
    beforeEach(() => {
      createComponent({ props: { heading: 'Custom title' } });
    });

    it('renders provided title', () => {
      expect(findPageHeading().text()).toContain('Custom title');
    });
  });
});

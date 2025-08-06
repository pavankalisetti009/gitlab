import { RouterLinkStub } from '@vue/test-utils';
import { GlLink, GlSprintf, GlExperimentBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GridstackWrapper from '~/vue_shared/components/customizable_dashboard/gridstack_wrapper.vue';
import AnalyticsCustomizableDashboard from 'ee/analytics/analytics_dashboards/components/analytics_customizable_dashboard.vue';
import { stubComponent } from 'helpers/stub_component';
import { trimText } from 'helpers/text_helper';
import { dashboard, betaDashboard } from '../mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');

describe('AnalyticsCustomizableDashboard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const $router = {
    push: jest.fn(),
  };

  const panelSlotSpy = jest.fn();
  const defaultSlots = {
    panel: panelSlotSpy,
  };

  const createWrapper = (
    props = {},
    { loadedDashboard = dashboard, routeParams = {}, scopedSlots = {} } = {},
  ) => {
    const loadDashboard = { ...loadedDashboard };

    wrapper = shallowMountExtended(AnalyticsCustomizableDashboard, {
      propsData: {
        dashboard: loadDashboard,
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
        GlSprintf,
        GridstackWrapper: stubComponent(GridstackWrapper, {
          props: ['value'],
          template: `<div data-testid="gridstack-wrapper">
              <template v-for="panel in value.panels">
                <slot name="panel" v-bind="{ panel }"></slot>
              </template>
          </div>`,
        }),
      },
      mocks: {
        $router,
        $route: {
          params: routeParams,
        },
      },
      scopedSlots: {
        ...defaultSlots,
        ...scopedSlots,
      },
    });
  };

  const findDashboardTitle = () => wrapper.findByTestId('dashboard-title');
  const findFilters = () => wrapper.findByTestId('dashboard-filters');
  const findDashboardDescription = () => wrapper.findByTestId('dashboard-description');
  const findGridstackWrapper = () => wrapper.findComponent(GridstackWrapper);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  describe('when mounted updates', () => {
    let wrapperLimited;

    beforeEach(() => {
      wrapperLimited = document.createElement('div');
      wrapperLimited.classList.add('container-fluid', 'container-limited');
      document.body.appendChild(wrapperLimited);

      createWrapper();
    });

    afterEach(() => {
      document.body.removeChild(wrapperLimited);
    });

    it('body container', () => {
      expect(document.querySelectorAll('.container-fluid.not-container-limited')).toHaveLength(1);
    });

    it('body container after destroy', () => {
      wrapper.destroy();

      expect(document.querySelectorAll('.container-fluid.not-container-limited')).toHaveLength(0);
      expect(document.querySelectorAll('.container-fluid.container-limited')).toHaveLength(1);
    });
  });

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the gridstack wrapper', () => {
      expect(findGridstackWrapper().props()).toMatchObject({
        value: dashboard,
      });
    });

    it('shows the dashboard title', () => {
      expect(findDashboardTitle().text()).toBe('Analytics Overview');
    });

    it('shows the dashboard description', () => {
      expect(findDashboardDescription().text()).toBe('This is a dashboard');
    });

    it('does not show the filters', () => {
      expect(findFilters().exists()).toBe(false);
    });

    it('does not show a dashboard documentation link', () => {
      expect(findDashboardDescription().findComponent(GlLink).exists()).toBe(false);
    });

    it('does not render the `Experiment/Beta` badge', () => {
      expect(findExperimentBadge().exists()).toBe(false);
    });
  });

  describe('when a dashboard has no description', () => {
    beforeEach(() => {
      createWrapper({}, { loadedDashboard: { ...dashboard, description: undefined } });
    });

    it('does not show the dashboard description', () => {
      expect(findDashboardDescription().exists()).toBe(false);
    });
  });

  describe('when a dashboard has an after-description slot', () => {
    beforeEach(() => {
      createWrapper(
        {},
        {
          scopedSlots: {
            'after-description': `<p>After description</p>`,
          },
        },
      );
    });

    it('does render after-description slot after the description', () => {
      expect(trimText(findDashboardDescription().text())).toEqual(
        'This is a dashboard After description',
      );
    });
  });

  describe('when a dashboard is in beta', () => {
    beforeEach(() => {
      createWrapper({}, { loadedDashboard: betaDashboard });
    });

    it('renders the `Beta` badge', () => {
      expect(findExperimentBadge().props().type).toBe('beta');
    });
  });

  describe('when a dashboard is an experiment', () => {
    beforeEach(() => {
      createWrapper({}, { loadedDashboard: { ...betaDashboard, status: 'experiment' } });
    });

    it('renders the `Experiment` badge', () => {
      expect(findExperimentBadge().props().type).toBe('experiment');
    });
  });

  describe('dashboard filters', () => {
    describe('default behavior', () => {
      beforeEach(() => {
        createWrapper(
          {},
          { scopedSlots: { filters: '<p data-testid="test-filters">Filters here</p>' } },
        );
      });

      it('renders the filters slot', () => {
        expect(findFilters().exists()).toBe(true);
        expect(wrapper.findByTestId('test-filters').exists()).toBe(true);
      });
    });
  });
});

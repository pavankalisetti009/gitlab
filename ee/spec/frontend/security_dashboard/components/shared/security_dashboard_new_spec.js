import { shallowMount } from '@vue/test-utils';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import OpenVulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import GroupSecurityDashboardV2 from 'ee/security_dashboard/components/shared/security_dashboard_new.vue';

describe('Security Dashboard (new version) - Component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(GroupSecurityDashboardV2, {
      propsData: {
        ...props,
      },
      stubs: {
        DashboardLayout,
        PanelsBase,
        OpenVulnerabilitiesOverTimeChart,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(DashboardLayout);

  const getDashboardConfig = () => findDashboardLayout().props('config');
  const getFirstPanel = () => getDashboardConfig().panels[0];

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
    });

    it('passes the correct dashboard configuration to the layout', () => {
      const dashboardConfig = getDashboardConfig();

      expect(dashboardConfig.title).toBe('Security dashboard');
      expect(dashboardConfig.description).toBe(
        'This dashboard provides an overview of your security vulnerabilities.',
      );
    });

    it('renders the panels with correct configuration', () => {
      const firstPanel = getFirstPanel();

      expect(firstPanel.title).toBe('Vulnerabilities over time');
      expect(firstPanel.component).toBe(OpenVulnerabilitiesOverTimeChart);
      expect(firstPanel.gridAttributes).toEqual({
        width: 7,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });
  });
});

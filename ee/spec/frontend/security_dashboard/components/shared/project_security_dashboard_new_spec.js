import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import ProjectSecurityDashboardNew from 'ee/security_dashboard/components/shared/project_security_dashboard_new.vue';

describe('Project Security Dashboard (new version) - Component', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ProjectSecurityDashboardNew);
  };

  const findDashboardLayout = () => wrapper.findComponent(DashboardLayout);
  const getDashboardConfig = () => findDashboardLayout().props('config');

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
  });
});

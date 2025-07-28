import { nextTick } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import ProjectSecurityDashboardNew from 'ee/security_dashboard/components/shared/project_security_dashboard_new.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/report_type_token.vue';
import ProjectVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/project_vulnerabilities_over_time_panel.vue';

jest.mock('~/alert');

describe('Project Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockProjectFullPath = 'project-1';

  const createComponent = () => {
    wrapper = shallowMountExtended(ProjectSecurityDashboardNew, {
      provide: {
        projectFullPath: mockProjectFullPath,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
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

    it('renders the panels with the correct configuration', () => {
      const firstPanel = getFirstPanel();

      expect(firstPanel.component).toBe(ProjectVulnerabilitiesOverTimePanel);
      expect(firstPanel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject([
        {
          type: 'reportType',
          title: 'Report type',
          multiSelect: true,
          unique: true,
          token: markRaw(ReportTypeToken),
          operators: OPERATORS_OR,
        },
      ]);
    });

    it('updates filters when filters-changed event is emitted', async () => {
      const newFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual(newFilters);
    });

    it('clears filters when empty filters object is emitted', async () => {
      const initialFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual(initialFilters);

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual({});
    });

    it('passes filters to the vulnerabilities over time panel', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual({ reportType });
    });
  });
});

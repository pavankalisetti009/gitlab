import { nextTick, markRaw } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  SEVERITY_LEVELS_KEYS,
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import ProjectSecurityDashboardNew from 'ee/security_dashboard/components/shared/project_security_dashboard_new.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';

jest.mock('~/alert');

describe('Project Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockProjectFullPath = 'project-1';
  const mockTrackedRefs = [
    { id: 'main', name: 'main', refType: 'branch', isDefault: true },
    { id: 'v1.0.0', name: 'v1.0.0', refType: 'tag', isDefault: false },
  ];

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectSecurityDashboardNew, {
      provide: {
        projectFullPath: mockProjectFullPath,
        trackedRefs: mockTrackedRefs,
        glFeatures: { vulnerabilitiesAcrossContexts: true },
        ...provide,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findDashboardDescription = () => wrapper.findComponent(SecurityDashboardDescription);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const getDashboardConfig = () => findDashboardLayout().props('config');
  const findPanelWithId = (panelId) => getDashboardConfig().panels.find(({ id }) => id === panelId);
  const getVulnerabilitiesOverTimePanel = () => findPanelWithId('1');
  const getTitle = () => wrapper.find('h1');

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(getTitle().text()).toBe('Security dashboard');
    });

    it('renders the description', () => {
      expect(findDashboardDescription().props('scope')).toBe('project');
    });

    it('renders the vulnerabilities over time panel with the correct configuration', () => {
      const vulnerabilitiesOverTimePanel = getVulnerabilitiesOverTimePanel();

      expect(vulnerabilitiesOverTimePanel.component).toBe(VulnerabilitiesOverTimePanel);
      expect(vulnerabilitiesOverTimePanel.componentProps.scope).toBe('project');
      expect(vulnerabilitiesOverTimePanel.componentProps.filters).toEqual({});
      expect(vulnerabilitiesOverTimePanel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });

    it('renders the severity panels with the correct configuration', () => {
      SEVERITY_LEVELS_KEYS.forEach((severity, index) => {
        const severityPanel = findPanelWithId(severity);

        expect(severityPanel.componentProps).toMatchObject({
          scope: 'project',
          severity,
          filters: {},
        });
        expect(severityPanel.gridAttributes).toEqual({
          width: 2,
          height: 1,
          yPos: 0,
          xPos: 2 * index,
        });
      });
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens including tracked ref token', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject([
        {
          type: 'reportType',
          title: 'Report type',
          multiSelect: true,
          unique: true,
          token: markRaw(ReportTypeToken),
          operators: OPERATORS_OR,
        },
        {
          type: 'trackedRefs',
          title: 'Tracked ref',
          multiSelect: false,
          unique: true,
          token: markRaw(TrackedRefToken),
          operators: OPERATORS_OR,
        },
      ]);
    });

    it('passes the correct reportTypes configuration to the ReportTypeToken', () => {
      const reportTypeToken = findFilteredSearch()
        .props('tokens')
        .find((token) => token.type === 'reportType');

      const expectedReportTypes = {
        ...REPORT_TYPES_WITH_MANUALLY_ADDED,
        ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
        ...REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
      };

      expect(reportTypeToken.reportTypes).toEqual(expectedReportTypes);
    });

    describe('when `trackedRefs` is empty', () => {
      beforeEach(() => {
        createComponent({ provide: { trackedRefs: [] } });
      });

      it('does not include tracked ref token', () => {
        const tokens = findFilteredSearch().props('tokens');

        expect(tokens).toHaveLength(1);
        expect(tokens[0].type).toBe('reportType');
      });
    });

    describe('when the `vulnerabilitiesAcrossContexts` feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({ provide: { glFeatures: { vulnerabilitiesAcrossContexts: false } } });
      });

      it('does not include tracked ref token', () => {
        const tokens = findFilteredSearch().props('tokens');

        expect(tokens).toHaveLength(1);
        expect(tokens[0].type).toBe('reportType');
      });
    });

    it('updates filters when filters-changed event is emitted', async () => {
      const newFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(newFilters);

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual(newFilters);
      });
    });

    it('clears filters when empty filters object is emitted', async () => {
      const initialFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(initialFilters);

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual(initialFilters);
      });

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({});

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual({});
      });
    });

    it('passes filters to the vulnerabilities over time panel', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({ reportType });
    });

    it('passes filters to all severity panels', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual({ reportType });
      });
    });
  });
});

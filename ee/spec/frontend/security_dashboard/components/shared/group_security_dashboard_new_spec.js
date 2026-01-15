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
import GroupSecurityDashboardNew from 'ee/security_dashboard/components/shared/group_security_dashboard_new.vue';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/project_token.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';
import GroupRiskScorePanel from 'ee/security_dashboard/components/shared/group_risk_score_panel.vue';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';

jest.mock('~/alert');

describe('Group Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockGroupFullPath = 'group/subgroup';

  const createComponent = ({
    props = {},
    newSecurityDashboardVulnerabilitiesByAge = true,
  } = {}) => {
    wrapper = shallowMountExtended(GroupSecurityDashboardNew, {
      propsData: {
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
        glFeatures: {
          newSecurityDashboardVulnerabilitiesByAge,
        },
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findDashboardDescription = () => wrapper.findComponent(SecurityDashboardDescription);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const getDashboardConfig = () => findDashboardLayout().props('config');
  const findPanelWithId = (panelId) => getDashboardConfig().panels.find(({ id }) => id === panelId);
  const getVulnerabilitiesOverTimePanel = () => findPanelWithId('vulnerabilities-over-time');
  const getVulnerabilitiesByAgePanel = () => findPanelWithId('vulnerabilities-by-age');
  const getRiskScorePanel = () => findPanelWithId('risk-score');
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
      expect(findDashboardDescription().props('scope')).toBe('group');
    });

    it('renders the risk score panel with the correct configuration', () => {
      const riskScorePanel = getRiskScorePanel();

      expect(riskScorePanel.component).toBe(GroupRiskScorePanel);
      expect(riskScorePanel.componentProps.filters).toEqual({});
      expect(riskScorePanel.gridAttributes).toEqual({
        width: 5,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });

    it('renders the vulnerabilities over time panel with the correct configuration', () => {
      const vulnerabilitiesOverTimePanel = getVulnerabilitiesOverTimePanel();

      expect(vulnerabilitiesOverTimePanel.component).toBe(VulnerabilitiesOverTimePanel);
      expect(vulnerabilitiesOverTimePanel.componentProps.scope).toBe('group');
      expect(vulnerabilitiesOverTimePanel.gridAttributes).toEqual({
        width: 7,
        height: 4,
        xPos: 5,
        yPos: 0,
      });
    });

    it('renders the severity panels with the correct configuration', () => {
      SEVERITY_LEVELS_KEYS.forEach((severity, index) => {
        const severityPanel = findPanelWithId(severity);

        expect(severityPanel.componentProps).toMatchObject({
          scope: 'group',
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

    it('renders the vulnerabilities by age panel with the correct configuration', () => {
      const vulnerabilitiesByAgePanel = getVulnerabilitiesByAgePanel();

      expect(vulnerabilitiesByAgePanel.component).toBe(VulnerabilitiesByAgePanel);
      expect(vulnerabilitiesByAgePanel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        xPos: 0,
        yPos: 5,
      });
    });

    it('does not render the vulnerabilities by age panel if the feature flag is disabled', () => {
      createComponent({ newSecurityDashboardVulnerabilitiesByAge: false });

      expect(getVulnerabilitiesByAgePanel()).toBeUndefined();
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'projectId',
            title: 'Project',
            multiSelect: true,
            unique: true,
            token: markRaw(ProjectToken),
            operators: OPERATORS_OR,
          }),
          expect.objectContaining({
            type: 'reportType',
            title: 'Report type',
            multiSelect: true,
            unique: true,
            token: markRaw(ReportTypeToken),
            operators: OPERATORS_OR,
          }),
        ]),
      );
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

    it('updates filters when filters-changed event is emitted', async () => {
      const newFilters = { projectId: ['gid://gitlab/Project/123'] };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(newFilters);
    });

    it('clears filters when empty filters object is emitted', async () => {
      const initialFilters = { projectId: ['gid://gitlab/Project/123'] };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(initialFilters);

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({});
    });

    it('passes filters to the vulnerabilities over time panel', async () => {
      const projectId = ['gid://gitlab/Project/123'];
      findFilteredSearch().vm.$emit('filters-changed', { projectId });
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({ projectId });
    });
  });
});

import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import PanelGroupBy from 'ee/security_dashboard/components/shared/panel_group_by.vue';
import PanelSeverityFilter from 'ee/security_dashboard/components/shared/panel_severity_filter.vue';

describe('VulnerabilitiesByAgePanel', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(VulnerabilitiesByAgePanel);
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findPanelGroupBy = () => wrapper.findComponent(PanelGroupBy);
  const findSeverityFilter = () => wrapper.findComponent(PanelSeverityFilter);

  const clickToggleButtonBy = async (value) => {
    await findPanelGroupBy().vm.$emit('input', value);
    await nextTick();
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the extended dashboard panel', () => {
      expect(findExtendedDashboardPanel().exists()).toBe(true);
    });

    it('passes the correct title to the panel', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities by age');
    });

    it('passes the correct tooltip to the panels base', () => {
      expect(findExtendedDashboardPanel().props('tooltip')).toEqual({
        description: 'Open vulnerabilities by the amount of time since they were opened.',
      });
    });

    it('passes severity value to PanelGroupBy by default', () => {
      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('renders all filter components', () => {
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findPanelGroupBy().exists()).toBe(true);
    });
  });

  describe('filters', () => {
    it('initializes severity if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesByAge.severity=HIGH%2CLOW');
      createComponent();

      expect(findSeverityFilter().props('value')).toMatchObject(['HIGH', 'LOW']);
    });

    it('calls writeToUrl when severity is set', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');
      createComponent();

      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);
      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesByAge',
        paramName: 'severity',
        value: ['CRITICAL', 'MEDIUM'],
        defaultValue: [],
      });
    });
  });

  describe('group by functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('switches to report type grouping when report type button is clicked', async () => {
      await clickToggleButtonBy('reportType');

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('switches back to severity grouping when severity button is clicked', async () => {
      await clickToggleButtonBy('reportType');
      await clickToggleButtonBy('severity');

      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('initializes with report type grouping if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesByAge.groupBy=reportType');
      createComponent();

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('calls writeToUrl when grouping is set to report type', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      await clickToggleButtonBy('reportType');

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesByAge',
        paramName: 'groupBy',
        value: 'reportType',
        defaultValue: 'severity',
      });
    });
  });
});

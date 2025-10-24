import { shallowMount } from '@vue/test-utils';
import { GlDashboardPanel, GlLink, GlSprintf } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import { SEVERITY_CLASS_NAME_MAP } from 'ee/vue_shared/security_reports/components/constants';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';

describe('VulnerabilitiesForSeverityPanel', () => {
  let wrapper;

  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findSingleStat = () => wrapper.findComponent(GlSingleStat);
  const findViewLink = () => wrapper.findComponent(GlLink);
  const findErrorMessage = () => wrapper.find('p');

  const defaultProps = {
    severity: 'critical',
    count: 42,
    filters: {
      reportType: ['SAST'],
    },
    error: false,
    loading: false,
  };
  const securityVulnerabilitiesPath = '/group/security/vulnerabilities';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(VulnerabilitiesForSeverityPanel, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        securityVulnerabilitiesPath,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('severities', () => {
    const severityLevelsTestCases = Object.entries(SEVERITY_LEVELS).map(
      ([severity, expectedTitle]) => ({ severity, expectedTitle }),
    );
    describe.each(severityLevelsTestCases)(
      'when severity is "$severity"',
      ({ severity, expectedTitle }) => {
        beforeEach(() => {
          createComponent({ props: { severity } });
        });

        it('shows the correct title', () => {
          expect(findDashboardPanel().props('title')).toBe(expectedTitle);
        });

        it('passes the correct icon', () => {
          expect(findDashboardPanel().props('titleIcon')).toBe(`severity-${severity}`);
        });

        it('passes the correct icon class color', () => {
          expect(findDashboardPanel().props('titleIconClass')).toBe(
            `gl-mr-3 ${SEVERITY_CLASS_NAME_MAP[severity]}`,
          );
        });

        it('constructs the correct link to the vulnerability report', () => {
          expect(findViewLink().props('href')).toBe(
            `${securityVulnerabilitiesPath}?state=CONFIRMED%2CDETECTED&severity=${severity.toUpperCase()}&reportType=SAST`,
          );
        });

        it('shows the correct info popover', () => {
          expect(findDashboardPanel().text()).toContain(
            `Total count of open ${expectedTitle} vulnerabilities. Click View to see these vulnerabilities in the vulnerability report.`,
          );
        });
      },
    );
  });

  describe('rendering states', () => {
    describe('normal state', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders GlSingleStat with correct value', () => {
        expect(findSingleStat().props('value')).toBe(defaultProps.count);
      });

      it('renders "View" link', () => {
        expect(findViewLink().text()).toBe('View');
      });

      it('does not render error message', () => {
        expect(findErrorMessage().exists()).toBe(false);
      });
    });

    describe('loading state', () => {
      beforeEach(() => {
        createComponent({ props: { loading: true } });
      });

      it('passes loading prop to dashboard panel', () => {
        expect(findDashboardPanel().props('loading')).toBe(true);
      });
    });

    describe('error state', () => {
      beforeEach(() => {
        createComponent({ props: { error: true } });
      });

      it('does not render GlSingleStat', () => {
        expect(findSingleStat().exists()).toBe(false);
      });

      it('renders error message', () => {
        expect(findErrorMessage().text()).toBe('Something went wrong. Please try again.');
      });

      it('shows alert state in dashboard panel', () => {
        expect(findDashboardPanel().attributes('show-alert-state')).toBe('true');
      });

      it('passes error icon, color class, and border styling', () => {
        expect(findDashboardPanel().props()).toMatchObject({
          titleIcon: 'error',
          titleIconClass: 'gl-text-red-500',
          borderColorClass: 'gl-border-t-red-500',
        });
      });
    });

    describe('zero count state', () => {
      beforeEach(() => {
        createComponent({ props: { count: 0 } });
      });

      it('displays 0 in GlSingleStat', () => {
        expect(findSingleStat().props('value')).toBe(0);
      });

      it('does not show any special empty state', () => {
        expect(findSingleStat().exists()).toBe(true);
        expect(findErrorMessage().exists()).toBe(false);
      });
    });
  });
});

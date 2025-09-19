import { GlAlert } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import MigrationAlert from 'ee/analytics/merge_request_analytics/components/migration_alert.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('MigrationAlert', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const analyticsDashboardsPath = 'analyticsDashboardsPath';
  const mrAnalyticsDashboardPath = 'mrAnalyticsDashboardPath';

  const createWrapper = ({ shouldShowCallout = true }) => {
    userCalloutDismissSpy = jest.fn();
    wrapper = mountExtended(MigrationAlert, {
      provide: {
        analyticsDashboardsPath,
        mrAnalyticsDashboardPath,
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);
  const findDashboardsListLink = () => wrapper.findByTestId('dashboardsListLink');
  const findMergeRequestDashboardLink = () => wrapper.findByTestId('mrDashboardLink');

  describe('when callout is hidden', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: false });
    });

    it('does not render the alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when callout is visible', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: true });
    });

    it('passes the correct feature name to the callout dismisser', () => {
      expect(findCalloutDismisser().props().featureName).toBe('mr_analytics_dashboard_migration');
    });

    it('renders the alert', () => {
      const title = 'Merge request analytics is moving';
      expect(findAlert().props().title).toBe(title);
      expect(findAlert().text()).toBe(
        `${title} This page will move to Analytics dashboards > Merge request analytics in GitLab 18.6.`,
      );
    });

    it('emits dismiss when alert is dismissed', () => {
      findAlert().vm.$emit('dismiss');
      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });

    it('generates the dashboard list link for the namespace', () => {
      expect(findDashboardsListLink().attributes('href')).toBe(analyticsDashboardsPath);
    });

    it('generates the MR dashboard link for the namespace', () => {
      expect(findMergeRequestDashboardLink().attributes('href')).toBe(mrAnalyticsDashboardPath);
    });
  });
});

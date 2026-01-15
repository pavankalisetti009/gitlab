import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';

describe('VulnerabilitiesByAgePanel', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(VulnerabilitiesByAgePanel);
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);

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
  });
});

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityFindingsPage from 'ee/merge_requests/reports/pages/security_findings_page.vue';

describe('Security findings page component', () => {
  let wrapper;

  const createComponent = ({ mr = {} } = {}) => {
    wrapper = shallowMountExtended(SecurityFindingsPage, {
      propsData: {
        mr: { isPipelineActive: false, ...mr },
      },
    });
  };

  const findSecurityFindingsPage = () => wrapper.findByTestId('security-findings-page');

  describe('rendering', () => {
    it('renders the security findings page', () => {
      createComponent();

      expect(findSecurityFindingsPage().exists()).toBe(true);
    });
  });
});

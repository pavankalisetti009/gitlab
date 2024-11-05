import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityListApp from 'ee/merge_requests/reports/components/security_list_item.vue';

describe('Merge request reports SecurityListApp component', () => {
  let wrapper;

  const findSecurityHeading = () => wrapper.findByTestId('security-item-heading');
  const findSecuritySubheading = () => wrapper.findByTestId('security-item-subheading');
  const findSecurityFinding = () => wrapper.findByTestId('security-item-finding');
  const findSecurityFindingStatusIcon = () =>
    wrapper.findByTestId('security-item-finding-status-icon');

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(SecurityListApp, {
      propsData: { policyName: 'Policy Name', loading: false, ...propsData },
      stubs: { GlSprintf },
    });
  };

  it('renders loading text', () => {
    createComponent({ loading: true });

    expect(findSecuritySubheading().text()).toBe('Results pending...');
  });

  describe('with findings', () => {
    it.each`
      findings                                      | text
      ${[]}                                         | ${'Policy `Policy Name` passed'}
      ${[{ name: 'Finding' }]}                      | ${'Policy `Policy Name` found 1 violation'}
      ${[{ name: 'Finding' }, { name: 'Finding' }]} | ${'Policy `Policy Name` found 2 violations'}
    `('renders "$text" subheading with $findings', ({ findings, text }) => {
      createComponent({ findings });

      expect(findSecurityHeading().text()).toBe(text);
    });

    it.each`
      findings                                      | text
      ${[]}                                         | ${'No policy violations found'}
      ${[{ name: 'Finding' }]}                      | ${'1 finding must be resolved'}
      ${[{ name: 'Finding' }, { name: 'Finding' }]} | ${'2 findings must be resolved'}
    `('renders "$text" subheading with $findings', ({ findings, text }) => {
      createComponent({ findings });

      expect(findSecuritySubheading().text()).toBe(text);
    });

    it('renders security finding text', () => {
      createComponent({ findings: [{ name: 'Finding', severity: 'high' }] });

      expect(findSecurityFinding().text()).toContain('High');
      expect(findSecurityFinding().text()).toContain('Finding');
    });

    it('renders security finding icon', () => {
      createComponent({ findings: [{ name: 'Finding', severity: 'high' }] });

      expect(findSecurityFindingStatusIcon().props('iconName')).toBe('severityHigh');
    });
  });
});

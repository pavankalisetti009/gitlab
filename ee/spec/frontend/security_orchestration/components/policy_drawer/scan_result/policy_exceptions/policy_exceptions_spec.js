import BranchPatternException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/branch_pattern_exception.vue';
import PolicyExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Policy Exceptions', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptions, {
      propsData,
    });
  };

  const findHeader = () => wrapper.findByTestId('header');
  const findSubHeader = () => wrapper.findByTestId('subheader');
  const findBranchPatternException = () => wrapper.findComponent(BranchPatternException);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders header', () => {
      expect(findHeader().text()).toBe('Policy Bypass Options');
      expect(findSubHeader().exists()).toBe(false);
    });
  });

  describe('saved exceptions', () => {
    it('renders branch exceptions', () => {
      const branches = [
        { source: { pattern: 'master' }, target: { name: '*test' } },
        { source: { pattern: 'main' }, target: { name: '*test2' } },
      ];
      createComponent({
        propsData: {
          exceptions: {
            branches,
          },
        },
      });

      expect(findBranchPatternException().exists()).toBe(true);
      expect(findBranchPatternException().props('branches')).toEqual(branches);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });
  });
});

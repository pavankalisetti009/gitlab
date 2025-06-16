import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';
import { SOURCE_BRANCH_PATTERNS } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import { mockBranchPatterns } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('PolicyExceptionsModal', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsModal, {
      propsData,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findBranchPatternSelector = () => wrapper.findComponent(BranchPatternSelector);
  const findPolicyExceptionsSelector = () => wrapper.findComponent(PolicyExceptionsSelector);
  const findSaveButton = () => wrapper.findByTestId('save-button');

  beforeEach(() => {
    createComponent();
  });

  describe('initial state', () => {
    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe(PolicyExceptionsModal.i18n.modalTitle);
      expect(modal.props('size')).toBe('md');
      expect(modal.props('modalId')).toBe('deny-allow-list-modal');

      expect(findPolicyExceptionsSelector().exists()).toBe(true);
    });
  });

  describe('branch patterns', () => {
    it('renders branch pattern selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            branches: mockBranchPatterns,
          },
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      expect(findBranchPatternSelector().exists()).toBe(true);
      expect(findBranchPatternSelector().props('branches')).toEqual(mockBranchPatterns);
    });

    it('saves selected branch patterns', async () => {
      createComponent({
        propsData: {
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      await findBranchPatternSelector().vm.$emit('set-branches', mockBranchPatterns);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            branches: mockBranchPatterns,
          },
        ],
      ]);
    });
  });
});

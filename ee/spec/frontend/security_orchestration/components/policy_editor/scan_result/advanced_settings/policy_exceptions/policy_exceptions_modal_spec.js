import { shallowMount } from '@vue/test-utils';
import { GlModal } from '@gitlab/ui';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';

describe('PolicyExceptionsModal', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(PolicyExceptionsModal, {
      propsData,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findPolicyExceptionsSelector = () => wrapper.findComponent(PolicyExceptionsSelector);

  beforeEach(() => {
    createComponent();
  });

  describe('initial state', () => {
    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe(PolicyExceptionsModal.i18n.modalTitle);
      expect(modal.props('actionCancel').text).toBe('Cancel');
      expect(modal.props('actionPrimary').text).toBe('Add exception(s)');
      expect(modal.props('size')).toBe('md');
      expect(modal.props('modalId')).toBe('deny-allow-list-modal');

      expect(findPolicyExceptionsSelector().exists()).toBe(true);
    });
  });
});

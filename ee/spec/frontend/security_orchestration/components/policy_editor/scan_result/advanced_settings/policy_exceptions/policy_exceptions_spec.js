import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';

describe('PolicyExceptions', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(PolicyExceptions, {
      propsData,
      stubs: { PolicyExceptionsModal },
    });
  };

  const findAddButton = () => wrapper.findComponent(GlButton);
  const findExceptionsModal = () => wrapper.findComponent(PolicyExceptionsModal);

  describe('initial rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders add button and exceptions modal', () => {
      expect(findAddButton().exists()).toBe(true);
      expect(findExceptionsModal().exists()).toBe(true);
      expect(findExceptionsModal().findComponent(GlModal).props('visible')).toBe(false);
    });
  });
});

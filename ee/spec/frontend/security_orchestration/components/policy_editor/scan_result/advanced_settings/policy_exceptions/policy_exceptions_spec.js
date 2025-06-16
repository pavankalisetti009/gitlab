import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import { mockBranchPatterns } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

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

  describe('branch patterns', () => {
    describe('selected branch patterns', () => {
      it('displays selected branch patterns', () => {
        createComponent({
          propsData: {
            exceptions: {
              branches: mockBranchPatterns,
            },
          },
        });

        expect(findExceptionsModal().props('exceptions')).toEqual({ branches: mockBranchPatterns });
      });

      it('emits changes when patterns are changed', () => {
        const payload = { branches: mockBranchPatterns };
        createComponent();

        findExceptionsModal().vm.$emit('changed', { branches: mockBranchPatterns });

        expect(wrapper.emitted('changed')).toEqual([['bypass_settings', payload]]);
      });
    });
  });
});

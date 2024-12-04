import { GlCollapsibleListbox } from '@gitlab/ui';
import DenyAllowExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_exceptions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EXCEPTION_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('DenyAllowExceptions', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowExceptions, {
      propsData,
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering', () => {
    it('renders default list with no exceptions', () => {
      createComponent();

      expect(findListBox().props('toggleText')).toBe('No exceptions');
    });

    it('selects exception type', () => {
      createComponent();

      findListBox().vm.$emit('select', EXCEPTION_KEY);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPTION_KEY]]);
    });

    it('renders selected license', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      expect(findListBox().props('selected')).toBe(EXCEPTION_KEY);
      expect(findListBox().props('toggleText')).toBe('Exceptions');
    });
  });
});

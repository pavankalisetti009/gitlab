import { GlLink, GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';

describe('AdvancedEditorToggle', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(AdvancedEditorToggle, {
      propsData,
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findToggle = () => wrapper.findComponent(GlToggle);

  describe('default rendering', () => {
    it('renders disabled toggle', () => {
      createComponent();

      expect(findToggle().exists()).toBe(true);
      expect(findToggle().props('label')).toBe('Try advanced editor');
      expect(findToggle().props('value')).toBe(false);
      expect(findLink().exists()).toBe(false);
    });

    it('renders enabled toggle', () => {
      createComponent({
        propsData: {
          advancedEditorEnabled: true,
        },
      });

      expect(findToggle().props('label')).toBe('Back to standard editor');
      expect(findToggle().props('value')).toBe(true);
      expect(findLink().exists()).toBe(true);
      expect(findLink().text()).toBe('Give us feedback');
    });
  });

  describe('event handling', () => {
    it('emits event when editor is toggled', () => {
      createComponent();

      findToggle().vm.$emit('change', true);

      expect(wrapper.emitted('enable-advanced-editor')).toEqual([[true]]);
    });
  });
});

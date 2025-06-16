import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchPatternItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_item.vue';

describe('BranchPatternItem', () => {
  let wrapper;

  const defaultBranchPattern = {
    source: { pattern: 'feature/*' },
    target: { name: 'main' },
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(BranchPatternItem, {
      propsData: {
        branch: props.branch || {},
        ...props,
      },
    });
  };

  const findSourceInput = () => wrapper.findByTestId('source-input');
  const findTargetInput = () => wrapper.findByTestId('target-input');
  const findRemoveButton = () => wrapper.findComponent(GlButton);

  describe('rendering', () => {
    it('renders the component with empty inputs when no pattern is provided', () => {
      createComponent();

      expect(findSourceInput().exists()).toBe(true);
      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().exists()).toBe(true);
      expect(findTargetInput().props('value')).toBe('');
      expect(findRemoveButton().exists()).toBe(true);
      expect(findRemoveButton().props('icon')).toBe('remove');
    });

    it('renders the component with pattern values when provided', () => {
      createComponent({ props: { branch: defaultBranchPattern } });

      expect(findSourceInput().props('value')).toBe('feature/*');
      expect(findTargetInput().props('value')).toBe('main');
    });

    it('renders the component with correct placeholders', () => {
      createComponent();

      expect(findSourceInput().props('placeholder')).toBe('input source branch');
      expect(findTargetInput().props('placeholder')).toBe('input target branch');
    });
  });

  describe('behavior', () => {
    it('emits remove event when remove button is clicked', () => {
      createComponent();

      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });

    it('handles branch pattern with missing source or target properties', () => {
      createComponent({
        props: {
          branch: {
            source: null,
            target: { name: 'main' },
          },
        },
      });

      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().props('value')).toBe('main');
    });

    it('handles branch with empty source pattern or target name', () => {
      createComponent({
        props: {
          branch: {
            source: { pattern: '' },
            target: { name: '' },
          },
        },
      });

      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().props('value')).toBe('');
    });

    it('emits branch patterns', async () => {
      createComponent();

      await findSourceInput().vm.$emit('input', 'source');

      expect(wrapper.emitted('set-branch')).toEqual([[{ source: { pattern: 'source' } }]]);

      await findTargetInput().vm.$emit('input', 'target');

      expect(wrapper.emitted('set-branch')[1]).toEqual([{ target: { name: 'target' } }]);
    });
  });
});

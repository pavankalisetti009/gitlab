import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PipelineSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/pipeline_source_selector.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import {
  PIPELINE_SOURCE_OPTIONS,
  TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('PipelineSourceSelector', () => {
  let wrapper;

  const createComponent = ({ showAllSources = true, including = [] } = {}) => {
    wrapper = shallowMountExtended(PipelineSourceSelector, {
      propsData: {
        showAllSources,
        pipelineSources: { including },
      },
    });
  };

  const findListbox = () => wrapper.findComponent(RuleMultiSelect);

  describe('rendering', () => {
    it('renders the dropdown with all sources by default', () => {
      createComponent();

      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('items')).toEqual(PIPELINE_SOURCE_OPTIONS);
      expect(listbox.props('value')).toEqual([]);
    });

    it('renders the dropdown with limited sources based on `showAllSources` prop', () => {
      createComponent({ showAllSources: false });

      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('items')).toEqual(TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS);
      expect(listbox.props('value')).toEqual([]);
    });

    it('renders selected sources in the dropdown', () => {
      const selectedSources = ['web', 'api'];
      createComponent({ including: selectedSources });

      expect(findListbox().props('value')).toEqual(selectedSources);
    });
  });

  describe('user interactions', () => {
    it('emits update event with selected sources when user selects a source', () => {
      createComponent();

      const selectedSources = ['web'];
      findListbox().vm.$emit('input', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with multiple selected sources', () => {
      createComponent({ including: ['web'] });

      const selectedSources = ['web', 'api'];
      findListbox().vm.$emit('input', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with empty array when all sources are deselected', () => {
      createComponent({ including: ['web', 'api'] });

      findListbox().vm.$emit('input', []);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: null },
      });
    });

    it('emits update event with all selected sources when user selects all sources', () => {
      createComponent();
      const allSources = Object.keys(PIPELINE_SOURCE_OPTIONS);

      findListbox().vm.$emit('input', allSources);

      expect(wrapper.emitted('select')).toBe(undefined);
      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });
});

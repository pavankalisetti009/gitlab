import { GlCollapsibleListbox } from '@gitlab/ui';
import VariablesSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';

describe('VariablesSelector', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(VariablesSelector, {
      propsData,
    });
  };

  const listBoxItems = FLAT_LIST_OPTIONS.map((item) => ({ value: item, text: item }));
  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  describe('default rendering', () => {
    it('renders variable selector', () => {
      createComponent();

      expect(findListBox().props('items')).toEqual(listBoxItems);
      expect(findListBox().props('toggleText')).toBe('Select a variable');
      expect(findListBox().props('selected')).toBe('');
    });
  });

  describe('selected variables', () => {
    it('renders selected variables', () => {
      createComponent({ propsData: { selected: FLAT_LIST_OPTIONS[0] } });

      expect(findListBox().props('selected')).toBe(FLAT_LIST_OPTIONS[0]);
    });

    it('renders reduced list when variable is already selected', () => {
      createComponent({
        propsData: { alreadySelectedItems: [FLAT_LIST_OPTIONS[0], FLAT_LIST_OPTIONS[1]] },
      });

      expect(findListBox().props('items')).toEqual(listBoxItems.slice(2));
      expect(findListBox().props('items')).not.toContain(FLAT_LIST_OPTIONS[0]);
      expect(findListBox().props('items')).not.toContain(FLAT_LIST_OPTIONS[1]);
    });
  });

  describe('searching', () => {
    it('searches through variables list', async () => {
      createComponent();

      await findListBox().vm.$emit('search', FLAT_LIST_OPTIONS[0]);

      expect(findListBox().props('items')).toEqual([listBoxItems[0]]);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('selects a variable', () => {
      findListBox().vm.$emit('select', FLAT_LIST_OPTIONS[0]);

      expect(wrapper.emitted('select')).toEqual([[FLAT_LIST_OPTIONS[0]]]);
    });

    it('removes selector', () => {
      findSectionLayout().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });
});

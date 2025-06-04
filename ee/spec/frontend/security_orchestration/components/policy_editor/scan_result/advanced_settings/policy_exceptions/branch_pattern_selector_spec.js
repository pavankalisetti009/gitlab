import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import BranchPatternItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_item.vue';

describe('BranchPatternSelector', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(BranchPatternSelector, {
      propsData: {
        patterns: [],
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAddPatternButton = () => wrapper.findByTestId('add-pattern');
  const findBranchPatternItems = () => wrapper.findAllComponents(BranchPatternItem);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findComponentHeader = () => wrapper.findByTestId('pattern-header');

  beforeEach(() => {
    createComponent();
  });

  describe('initial rendering', () => {
    it('displays the title', () => {
      expect(findComponentHeader().text()).toContain(
        'Define branch patterns that can bypass policy requirements using wildcards and regex patterns. Use * for simple wildcards or regex patterns for advanced matching. Learn more',
      );
    });

    it('renders the help link with correct URL', () => {
      expect(findHelpLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected',
      );
      expect(findHelpLink().attributes('target')).toBe('_blank');
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('creates a default pattern item when no patterns are provided', () => {
      expect(findBranchPatternItems()).toHaveLength(1);
    });

    it('renders the add pattern button with correct text', () => {
      const button = findAddPatternButton();
      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Add new criteria');
      expect(button.props()).toMatchObject({
        icon: 'plus',
        category: 'tertiary',
        variant: 'confirm',
        size: 'small',
      });
    });
  });

  describe('with provided patterns', () => {
    const mockPatterns = [
      { id: 'pattern_1', source: 'main-*', target: 'target-1' },
      { id: 'pattern_2', source: 'feature-.*', target: 'target-2' },
    ];

    beforeEach(() => {
      createComponent({ patterns: mockPatterns });
    });

    it('maps and renders all provided patterns', () => {
      expect(findBranchPatternItems()).toHaveLength(2);
      expect(findBranchPatternItems().at(0).props('pattern')).toEqual(mockPatterns[0]);
      expect(findBranchPatternItems().at(1).props('pattern')).toEqual(mockPatterns[1]);
    });
  });

  describe('user interactions', () => {
    it('adds a new pattern when add button is clicked', async () => {
      expect(findBranchPatternItems()).toHaveLength(1);

      await findAddPatternButton().vm.$emit('click');

      expect(findBranchPatternItems()).toHaveLength(2);
    });

    it('removes a pattern when remove event is emitted', async () => {
      await findAddPatternButton().vm.$emit('click');
      expect(findBranchPatternItems()).toHaveLength(2);

      await findBranchPatternItems().at(0).vm.$emit('remove');

      expect(findBranchPatternItems()).toHaveLength(1);
    });
  });
});

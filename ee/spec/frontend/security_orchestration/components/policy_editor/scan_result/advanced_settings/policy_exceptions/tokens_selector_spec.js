import { GlAlert, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TokensSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/tokens_selector.vue';
import { mockTokens } from './mocks';

describe('TokensSelector', () => {
  let wrapper;

  const defaultProvide = {
    accessTokens: mockTokens,
  };

  const defaultProps = {
    tokens: [],
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(TokensSelector, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findFormCheckboxGroup = () => wrapper.findByTestId('recently-selected-list');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders form group with correct props', () => {
      expect(findFormGroup().attributes()).toMatchObject({
        id: 'tokens-list',
        optionaltext: '(optional)',
        'label-for': 'tokens-list',
        label: 'Select token exceptions',
        description: 'Apply this approval rule to any branch or a specific protected branch.',
      });
    });

    it('renders collapsible listbox with correct props', () => {
      expect(findCollapsibleListbox().props()).toMatchObject({
        block: true,
        multiple: true,
        searchable: true,
        selected: [],
        headerText: 'Access tokens',
        loading: false,
        toggleText: 'Select access token',
      });
    });

    it('does not render alert initially', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('renders recently created section', () => {
      expect(wrapper.text()).toContain('Recently created');
    });
  });

  describe('token selection', () => {
    beforeEach(() => {
      createComponent({
        tokens: mockTokens.slice(0, 2),
      });
    });

    it('displays selected tokens correctly', () => {
      expect(findCollapsibleListbox().props('selected')).toEqual([1, 2]);
    });

    it('emits set-tokens event when tokens are selected via listbox', async () => {
      await findCollapsibleListbox().vm.$emit('select', [1, 3]);

      expect(wrapper.emitted('set-tokens')).toEqual([[[{ id: 1 }, { id: 3 }]]]);
    });

    it('emits set-tokens event when tokens are selected via checkbox group', async () => {
      await findFormCheckboxGroup().vm.$emit('input', [2, 4]);

      expect(wrapper.emitted('set-tokens')).toEqual([[[{ id: 2 }, { id: 4 }]]]);
    });

    it('shows correct toggle text for multiple selections', () => {
      expect(findCollapsibleListbox().props('toggleText')).toBe('project-token-1, project-token-2');
    });

    it('shows correct toggle text for single selection', async () => {
      createComponent({ tokens: [{ id: 1 }] });
      await waitForPromises();

      expect(findCollapsibleListbox().props('toggleText')).toBe('project-token-1');
    });

    it('shows default text when no tokens selected', () => {
      createComponent({ tokens: [] });
      expect(findCollapsibleListbox().props('toggleText')).toBe('Select access token');
    });
  });

  describe('search functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('handles search input with debouncing', async () => {
      const searchTerm = 'project-token-1';
      await findCollapsibleListbox().vm.$emit('search', searchTerm);

      // Wait for debounce
      jest.advanceTimersByTime(250);

      expect(wrapper.vm.searchTerm).toBe(searchTerm);
    });

    it('filters items based on search term', async () => {
      await findCollapsibleListbox().vm.$emit('search', 'project-token-1');

      expect(findCollapsibleListbox().props('items')).toEqual([
        { text: 'project-token-1', value: 1 },
      ]);
    });
  });

  describe('recently used tokens', () => {
    beforeEach(() => {
      createComponent({ tokens: mockTokens.slice(0, 2) });
    });

    it('displays recently used tokens in checkbox group', async () => {
      await waitForPromises();
      const checkboxGroup = findFormCheckboxGroup();
      expect(checkboxGroup.exists()).toBe(true);

      expect(checkboxGroup.props('options')).toHaveLength(3); // RECENTLY_USED_TOKENS_MAX
      expect(checkboxGroup.attributes('checked')).toEqual('1,2');
    });

    it('shows message when no tokens are created', () => {
      createComponent({}, { accessTokens: [] });

      expect(wrapper.text()).toContain('There are no access tokens created');
      expect(findFormCheckboxGroup().exists()).toBe(false);
    });
  });

  describe('computed properties', () => {
    beforeEach(() => {
      createComponent();
    });

    it('formats listbox items correctly', () => {
      const expectedItems = [
        { text: 'project-token-1', value: 1 },
        { text: 'project-token-2', value: 2 },
        { text: 'project-token-3', value: 3 },
        { text: 'project-token-4', value: 4 },
      ];
      expect(findCollapsibleListbox().props('items')).toEqual(expectedItems);
    });
  });

  describe('edge cases', () => {
    it('handles empty tokens prop', () => {
      createComponent({ tokens: [] });
      expect(findCollapsibleListbox().props('selected')).toEqual([]);
    });

    it('handles undefined tokens prop', () => {
      createComponent({ tokens: undefined }, { accessTokens: undefined });
      expect(findCollapsibleListbox().props('items')).toEqual([]);
    });
  });
});

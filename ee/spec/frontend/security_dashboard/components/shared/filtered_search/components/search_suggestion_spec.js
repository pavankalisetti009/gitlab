import { GlFilteredSearchSuggestion, GlTruncate, GlIcon } from '@gitlab/ui';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

describe('Search Suggestion', () => {
  let wrapper;

  const createWrapper = ({ text, name, value, selected, truncate, tooltipText }) => {
    wrapper = shallowMountExtended(SearchSuggestion, {
      propsData: {
        text,
        name,
        value,
        selected,
        truncate,
        tooltipText,
      },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });
  };

  const findGlSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);

  it.each`
    selected
    ${true}
    ${false}
  `('renders search suggestions as expected when selected is $selected', ({ selected }) => {
    createWrapper({
      text: 'My text',
      value: 'my_value',
      selected,
    });

    expect(findGlSearchSuggestion().exists()).toBe(true);
    expect(wrapper.findByText('My text').exists()).toBe(true);
    expect(findGlSearchSuggestion().props('value')).toBe('my_value');
    expect(wrapper.findComponent(GlIcon).classes('gl-invisible')).toBe(!selected);
  });

  it.each`
    truncate
    ${true}
    ${false}
  `('truncates the text when `truncate` property is $truncate', ({ truncate }) => {
    createWrapper({ text: 'My text', value: 'My value', selected: false, truncate });
    expect(wrapper.findComponent(GlTruncate).exists()).toBe(truncate);
  });

  it('truncates the text when `truncate` property is $truncate', () => {
    createWrapper({ text: 'My text', value: 'My value', selected: false, truncate: true });
    expect(wrapper.findComponent(GlTruncate).props('text')).toBe('My text');
  });

  describe('tooltip', () => {
    const findTooltipIcon = () => wrapper.findByTestId('tooltip-icon');

    it('shows tooltip icon when tooltipText is provided', () => {
      const tooltipText = 'Help text';

      createWrapper({
        text: 'My text',
        value: 'my_value',
        selected: false,
        tooltipText,
      });
      const tooltip = getBinding(findTooltipIcon().element, 'gl-tooltip');
      expect(tooltip).toBeDefined();
      expect(findTooltipIcon().attributes('title')).toBe(tooltipText);
    });

    it('hides tooltip icon when tooltipText is empty', () => {
      createWrapper({
        text: 'My text',
        value: 'my_value',
        selected: false,
      });
      expect(findTooltipIcon().exists()).toBe(false);
    });
  });
});

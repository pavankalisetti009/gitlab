import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { mockListItems as mockSelfHostedModelsItems } from '../../duo_self_hosted/self_hosted_models/mock_data';
import { mockListItems as mockModelSelectionItems } from '../../model_selection/mock_data';

describe('ModelSelectDropdown', () => {
  let wrapper;

  const placeholderDropdownText = 'Select model';
  const selectedOption = mockSelfHostedModelsItems[0];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = extendedWrapper(
      mount(ModelSelectDropdown, {
        propsData: {
          items: mockSelfHostedModelsItems,
          placeholderDropdownText,
          selectedOption,
          ...props,
        },
      }),
    );
  };

  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findGLCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownListItems = () => wrapper.findAllByRole('option');
  const findDropdownToggleText = () => wrapper.findByTestId('dropdown-toggle-text');
  const findBetaModelSelectedBadge = () => wrapper.findByTestId('beta-model-selected-badge');
  const findBetaModelDropdownBadges = () => wrapper.findAllByTestId('beta-model-dropdown-badge');
  const findDefaultModelSelectedBadge = () => wrapper.findByTestId('default-model-selected-badge');
  const findDefaultModelDropdownBadge = () => wrapper.findByTestId('default-model-dropdown-badge');
  const findToggleButton = () => wrapper.findByTestId('toggle-button');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelectDropdown().exists()).toBe(true);
  });

  describe('dropdown toggle text', () => {
    it('renders the placeholder text when no selected option is provided', () => {
      createComponent({
        props: { selectedOption: null },
      });

      expect(findDropdownToggleText().text()).toBe(placeholderDropdownText);
    });

    it('displays the text based on selected option', () => {
      createComponent();

      expect(findDropdownToggleText().text()).toBe(selectedOption.text);
    });
  });

  describe('items', () => {
    it('renders list items', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('items')).toBe(mockSelfHostedModelsItems);
    });

    it('can handle model selection items', () => {
      createComponent({ props: { items: mockModelSelectionItems } });

      expect(findGLCollapsibleListbox().props('items')).toBe(mockModelSelectionItems);
      expect(findDropdownListItems().at(0).text()).toEqual('Claude Sonnet 3.5 - Anthropic');
      expect(findDropdownListItems().at(1).text()).toEqual('Claude Sonnet 3.7 - Anthropic');
    });

    it('sets a default selected value based on the selected option', () => {
      createComponent({
        props: {
          selectedOption,
        },
      });

      const dropdown = findGLCollapsibleListbox();

      // selected based on selected option prop
      expect(dropdown.props('selected')).toBe(selectedOption.value);
    });

    it('emits select event when an item is selected', async () => {
      createComponent();

      findGLCollapsibleListbox().vm.$emit('select', selectedOption.value);
      await nextTick();

      expect(wrapper.emitted('select')).toStrictEqual([[selectedOption.value]]);
    });
  });

  describe('when isLoading is true', () => {
    it('renders the loading state', () => {
      createComponent({ props: { isLoading: true } });

      expect(findGLCollapsibleListbox().props('loading')).toBe(true);
    });
  });

  describe('when disabled is true', () => {
    it('disables the dropdown toggle', () => {
      createComponent({ props: { disabled: true } });
      expect(findToggleButton().props('disabled')).toBe(true);
    });
  });

  describe('beta model items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the beta badge with dropdown options', () => {
      expect(findBetaModelDropdownBadges()).toHaveLength(3);
    });

    it('displays the beta badge when beta option is selected', () => {
      const betaModel = mockSelfHostedModelsItems[1];

      createComponent({ props: { selectedOption: betaModel } });

      expect(findBetaModelSelectedBadge().exists()).toBe(true);
    });
  });

  describe('default model items', () => {
    const mockDefaultModel = {
      value: GITLAB_DEFAULT_MODEL,
      text: 'GitLab default model (Claude Sonnet 3.7 - Anthropic)',
    };
    it('displays the default model badge with dropdown option', () => {
      createComponent({ props: { items: mockModelSelectionItems } });

      const defaultModel = findDropdownListItems().at(3);

      expect(defaultModel.text()).toMatch('GitLab default model (Claude Sonnet 3.7 - Anthropic)');
      expect(findDefaultModelDropdownBadge().exists()).toBe(true);
      expect(findDefaultModelDropdownBadge().attributes('title')).toBe('');
    });

    it('displays the default model badge when option is selected', () => {
      createComponent({
        props: {
          selectedOption: mockDefaultModel,
        },
      });

      expect(findDefaultModelSelectedBadge().exists()).toBe(true);
      expect(findDefaultModelSelectedBadge().attributes('title')).toBe('');
    });

    describe('when `withDefaultModelTooltip` is passed', () => {
      it('displays a tooltip for the default model badge in dropdown option', () => {
        createComponent({
          props: { items: mockModelSelectionItems, withDefaultModelTooltip: true },
        });

        expect(findDefaultModelDropdownBadge().attributes('title')).toBe('GitLab default model');
      });

      it('displays a tooltip for the default model badge as selected option', () => {
        createComponent({
          props: { selectedOption: mockDefaultModel, withDefaultModelTooltip: true },
        });

        expect(findDefaultModelSelectedBadge().attributes('title')).toBe('GitLab default model');
      });
    });
  });
});

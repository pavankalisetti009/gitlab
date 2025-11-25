import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
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
  const findDropdownToggleText = () => wrapper.findByTestId('dropdown-toggle-text');
  const findModelNames = () => wrapper.findAllByTestId('model-name');
  const findModelProviders = () => wrapper.findAllByTestId('model-provider');
  const findModelDescriptions = () => wrapper.findAllByTestId('model-description');
  const findBetaModelSelectedBadge = () => wrapper.findByTestId('beta-model-selected-badge');
  const findBetaModelDropdownBadges = () => wrapper.findAllByTestId('beta-model-dropdown-badge');
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

  describe('items', () => {
    it('renders list items', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('items')).toBe(mockSelfHostedModelsItems);
    });

    describe('Self-hosted model items', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders model names', () => {
        mockSelfHostedModelsItems.forEach((item, index) => {
          expect(findModelNames().at(index).text()).toEqual(item.text);
        });
      });

      describe('beta models', () => {
        it('displays the beta badge with dropdown options', () => {
          expect(findBetaModelDropdownBadges()).toHaveLength(3);
        });

        it('displays the beta badge when beta option is selected', () => {
          const betaModel = mockSelfHostedModelsItems[1];

          createComponent({ props: { selectedOption: betaModel } });

          expect(findBetaModelSelectedBadge().exists()).toBe(true);
        });
      });
    });

    describe('GitLab model items', () => {
      beforeEach(() => {
        createComponent({ props: { items: mockModelSelectionItems } });
      });

      it('renders model names', () => {
        mockModelSelectionItems.forEach((item, index) => {
          expect(findModelNames().at(index).text()).toEqual(item.text);
        });
      });

      it('renders model providers', () => {
        mockModelSelectionItems.forEach((item, index) => {
          expect(findModelProviders().at(index).text()).toEqual(item.provider);
        });
      });

      it('renders model descriptions', () => {
        mockModelSelectionItems.forEach((item, index) => {
          expect(findModelDescriptions().at(index).text()).toEqual(item.description);
        });
      });
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
});

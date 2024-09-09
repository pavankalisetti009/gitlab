import { GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ModelSelectDropdown from 'ee/pages/admin/ai/feature_settings/components/model_select_dropdown.vue';
import { mockSelfHostedModels } from './mock_data';

describe('ModelSelectDropdown', () => {
  let wrapper;

  const newSelfHostedModelPath = '/admin/ai/self_hosted_models/new';

  const createComponent = ({ props }) => {
    wrapper = mountExtended(ModelSelectDropdown, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent({
      props: {
        models: mockSelfHostedModels,
        newSelfHostedModelPath,
      },
    });
  });

  const findSelectDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectDropdownButtonText = () => wrapper.find('[class="gl-new-dropdown-button-text"]');
  const findButton = () => wrapper.find('[data-testid="add-self-hosted-model-button"]');

  it('renders the dropdown component', () => {
    expect(findSelectDropdown().exists()).toBe(true);
  });

  it('renders a list of select options', () => {
    const modelOptions = findSelectDropdown().props('items');

    expect(modelOptions.map((model) => model.text)).toEqual([
      'Model 1 (mistral)',
      'Model 2 (mixtral)',
      'Model 3 (codegemma)',
      'Disabled',
    ]);
  });

  it('renders a button to add a self-hosted model', () => {
    expect(findButton().text()).toBe('Add self-hosted model');
  });

  describe('when no model is selected and the feature is not disabled', () => {
    it('displays the correct text on the dropdown button', () => {
      expect(findSelectDropdownButtonText().text()).toBe('Select a self-hosted model');
    });
  });

  describe('when the feature is disabled', () => {
    it('displays the correct text on the dropdown button', async () => {
      findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 'DISABLED');

      expect(findSelectDropdownButtonText().text()).toBe('Disabled');
    });
  });

  describe('when a model is selected', () => {
    it('displays the selected deployment name and model', async () => {
      const selectedModel = mockSelfHostedModels[0];

      findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', selectedModel.id);

      expect(findSelectDropdownButtonText().text()).toBe(
        `${selectedModel.name} (${selectedModel.model})`,
      );
    });
  });
});

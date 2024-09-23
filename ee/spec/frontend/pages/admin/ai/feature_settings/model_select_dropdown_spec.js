import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlToast } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelectDropdown from 'ee/pages/admin/ai/feature_settings/components/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/pages/admin/ai/feature_settings/graphql/mutations/update_ai_feature_setting.graphql';
import { createAlert } from '~/alert';
import { mockSelfHostedModels, mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('ModelSelectDropdown', () => {
  let wrapper;

  const newSelfHostedModelPath = '/admin/ai/self_hosted_models/new';
  const mockAiFeatureSetting = mockAiFeatureSettings[0];

  const updateMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[updateAiFeatureSetting, updateMutationSuccessHandler]],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mount(ModelSelectDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        newSelfHostedModelPath,
        featureSetting: mockAiFeatureSetting,
        models: mockSelfHostedModels,
        ...props,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  beforeEach(() => {
    createComponent();
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

  describe('when an update is saving', () => {
    it('renders the loading state', async () => {
      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 'DISABLED');

      expect(findSelectDropdown().props('loading')).toBe(true);
    });
  });

  describe('when an update succeeds', () => {
    it('displays a success toast', async () => {
      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 'DISABLED');

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated Code Suggestions / Code Generation',
      );
    });

    describe('when the feature has been disabled', () => {
      it('displays the correct text on the dropdown button', async () => {
        await findSelectDropdownButtonText().trigger('click');
        await findSelectDropdown().vm.$emit('select', 'DISABLED');

        await waitForPromises();

        expect(findSelectDropdownButtonText().text()).toBe('Disabled');
      });
    });

    describe('when a model has been selected', () => {
      it('displays the selected deployment name and model', async () => {
        const selectedModel = mockSelfHostedModels[0];

        await findSelectDropdownButtonText().trigger('click');
        await findSelectDropdown().vm.$emit('select', selectedModel.id);

        await waitForPromises();

        expect(findSelectDropdownButtonText().text()).toBe(
          `${selectedModel.name} (${selectedModel.model})`,
        );
      });
    });
  });

  describe('when an update fails', () => {
    const selectedModel = mockSelfHostedModels[0];
    const updateMutationErrorHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettingUpdate: {
          aiFeatureSetting: null,
          errors: ['Codegemma is incompatible with the Duo Chat feature'],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        apolloHandlers: [[updateAiFeatureSetting, updateMutationErrorHandler]],
      });

      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', selectedModel.id);

      await waitForPromises();
    });

    it('does not update the selected option', () => {
      expect(findSelectDropdownButtonText().text()).toBe('Select a self-hosted model');
    });

    it('displays an error message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Codegemma is incompatible with the Duo Chat feature',
        }),
      );
    });
  });
});

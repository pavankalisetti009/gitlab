import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlToast } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelectDropdown from 'ee/pages/admin/ai/feature_settings/components/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/pages/admin/ai/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { createAlert } from '~/alert';
import { mockSelfHostedModels, mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('ModelSelectDropdown', () => {
  let wrapper;

  const mockAiFeatureSetting = mockAiFeatureSettings[0];

  const updateFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        errors: [],
      },
    },
  });

  const getFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        errors: [],
      },
    },
  });

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateAiFeatureSetting, updateFeatureSettingsSuccessHandler],
      [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
      [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mount(ModelSelectDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        aiFeatureSetting: mockAiFeatureSetting,
        ...props,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  const findSelectDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectDropdownButtonText = () => wrapper.find('[class="gl-new-dropdown-button-text"]');
  const findButton = () => wrapper.find('[data-testid="add-self-hosted-model-button"]');

  it('renders the dropdown component', () => {
    createComponent();

    expect(findSelectDropdown().exists()).toBe(true);
  });

  it('renders a list of select options', () => {
    createComponent();

    const modelOptions = findSelectDropdown().props('items');

    expect(modelOptions.map((model) => model.text)).toEqual([
      'Model 1 (Mistral)',
      'Model 2 (Code Llama)',
      'Model 3 (CodeGemma)',
      'GitLab AI Vendor',
      'Disabled',
    ]);
  });

  it('renders a button to add a self-hosted model', () => {
    createComponent();

    expect(findButton().text()).toBe('Add self-hosted model');
  });

  describe('when an update is saving', () => {
    it('renders the loading state', async () => {
      createComponent();

      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 'disabled');

      expect(findSelectDropdown().props('loading')).toBe(true);
    });
  });

  describe('Updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('with a vendored model', () => {
      it('calls the update mutation with the right input', async () => {
        await findSelectDropdown().vm.$emit('select', 'vendored');

        await waitForPromises();

        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            feature: 'CODE_GENERATIONS',
            provider: 'VENDORED',
            aiSelfHostedModelId: null,
          },
        });
      });
    });

    describe('with a self-hosted model', () => {
      it('calls the update mutation with the right input', async () => {
        await findSelectDropdown().vm.$emit('select', 1);

        await waitForPromises();

        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            feature: 'CODE_GENERATIONS',
            provider: 'SELF_HOSTED',
            aiSelfHostedModelId: 1,
          },
        });
      });
    });

    describe('disabling the feature', () => {
      it('calls the update mutation with the right input', async () => {
        await findSelectDropdown().vm.$emit('select', 'disabled');

        await waitForPromises();

        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            feature: 'CODE_GENERATIONS',
            provider: 'DISABLED',
            aiSelfHostedModelId: null,
          },
        });
      });
    });

    it('displays a success toast', async () => {
      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 1);

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated Code Suggestions / Code Generation',
      );
    });

    it('refreshes self-hosted models and feature settings data', async () => {
      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', 1);

      await waitForPromises();

      expect(getSelfHostedModelsSuccessHandler).toHaveBeenCalled();
      expect(getFeatureSettingsSuccessHandler).toHaveBeenCalled();
    });

    describe('when the feature state is changed', () => {
      it('displays the correct text on the dropdown button', async () => {
        expect(findSelectDropdownButtonText().text()).toBe('GitLab AI Vendor');

        await findSelectDropdown().vm.$emit('select', 'disabled');

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
          `${selectedModel.name} (${selectedModel.modelDisplayName})`,
        );
      });
    });
  });

  describe('when an update fails', () => {
    const selectedModel = mockSelfHostedModels[0];
    const updateFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettingUpdate: {
          aiFeatureSetting: null,
          errors: ['Codegemma is incompatible with the Duo Chat feature'],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        apolloHandlers: [
          [updateAiFeatureSetting, updateFeatureSettingsErrorHandler],
          [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
          [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
        ],
      });

      await findSelectDropdownButtonText().trigger('click');
      await findSelectDropdown().vm.$emit('select', selectedModel.id);

      await waitForPromises();
    });

    it('does not update the selected option', () => {
      expect(findSelectDropdownButtonText().text()).toBe('GitLab AI Vendor');
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

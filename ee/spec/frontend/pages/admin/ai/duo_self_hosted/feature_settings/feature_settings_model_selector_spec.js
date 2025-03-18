import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettingsModelSelector from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/feature_settings_model_selector.vue';
import ModelSelectDropdown from 'ee/pages/admin/ai/duo_self_hosted/shared/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/duo_self_hosted/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { createAlert } from '~/alert';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { mockSelfHostedModels, mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('FeatureSettingsModelSelector', () => {
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

    wrapper = extendedWrapper(
      shallowMount(FeatureSettingsModelSelector, {
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
      }),
    );
  };

  const findFeatureSettingsModelSelector = () =>
    wrapper.findComponent(FeatureSettingsModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findDropdownToggleText = () => findModelSelectDropdown().props('dropdownToggleText');

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsModelSelector().exists()).toBe(true);
  });

  describe('.listItems', () => {
    it('contains a list of options sorted by release state', () => {
      createComponent();

      const modelOptions = findModelSelectDropdown().props('items');

      expect(modelOptions.map(({ text, releaseState }) => [text, releaseState])).toEqual([
        ['Model 1 (Mistral)', 'GA'],
        ['Model 4 (GPT)', 'GA'],
        ['Model 5 (Claude 3)', 'GA'],
        ['Model 2 (Code Llama)', 'BETA'],
        ['Model 3 (CodeGemma)', 'BETA'],
        ['Disabled'],
      ]);
    });
  });

  describe('when an update is saving', () => {
    it('updates the loading state', async () => {
      createComponent();

      await findModelSelectDropdown().vm.$emit('select', 'disabled');

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('with a self-hosted model', () => {
      it('calls the update mutation with the right input', () => {
        findModelSelectDropdown().vm.$emit('select', 1);

        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            features: ['CODE_GENERATIONS'],
            provider: 'SELF_HOSTED',
            aiSelfHostedModelId: 1,
          },
        });
      });
    });

    describe('disabling the feature', () => {
      it('calls the update mutation with the right input', () => {
        findModelSelectDropdown().vm.$emit('select', 'disabled');

        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            features: ['CODE_GENERATIONS'],
            provider: 'DISABLED',
            aiSelfHostedModelId: null,
          },
        });
      });
    });

    it('triggers a success toast', async () => {
      findModelSelectDropdown().vm.$emit('select', 1);

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated Code Suggestions / Code Generation',
      );
    });

    it('refreshes self-hosted models and feature settings data', async () => {
      findModelSelectDropdown().vm.$emit('select', 1);

      await waitForPromises();

      expect(getSelfHostedModelsSuccessHandler).toHaveBeenCalled();
      expect(getFeatureSettingsSuccessHandler).toHaveBeenCalled();
    });

    describe('when the feature state is changed', () => {
      it('updates the dropdown toggle text', async () => {
        expect(findDropdownToggleText()).toBe('Select a self-hosted model');

        findModelSelectDropdown().vm.$emit('select', 'disabled');

        await waitForPromises();

        expect(findDropdownToggleText()).toBe('Disabled');
      });
    });

    describe('when a model has been selected', () => {
      it('displays the selected deployment name and model', async () => {
        const selectedModel = mockSelfHostedModels[0];

        findModelSelectDropdown().vm.$emit('select', selectedModel.id);

        await waitForPromises();

        expect(findDropdownToggleText()).toBe(
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

      findModelSelectDropdown().vm.$emit('select', selectedModel.id);

      await waitForPromises();
    });

    it('does not update the selected option', () => {
      expect(findModelSelectDropdown().props('dropdownToggleText')).toEqual(
        'Select a self-hosted model',
      );
    });

    it('triggers an error message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Codegemma is incompatible with the Duo Chat feature',
        }),
      );
    });
  });
});

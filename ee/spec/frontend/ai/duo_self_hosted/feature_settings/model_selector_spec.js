import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelector from 'ee/ai/duo_self_hosted/feature_settings/components/model_selector.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/ai/duo_self_hosted/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/ai/duo_self_hosted/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { PROVIDERS } from 'ee/ai/duo_self_hosted/feature_settings/constants';
import { createAlert } from '~/alert';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { mockSelfHostedModels, mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('ModelSelector', () => {
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
    injectedProps = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        apolloProvider: mockApollo,
        provide: {
          showVendoredModelOption: true,
          ...injectedProps,
        },
        propsData: {
          aiFeatureSetting: mockAiFeatureSetting,
          batchUpdateIsSaving: false,
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

  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  describe('.listItems', () => {
    it('contains a list of options sorted by release state', () => {
      createComponent();

      const modelOptions = findModelSelectDropdown().props('items');

      expect(
        modelOptions.map(({ text, releaseState }) => {
          const withReleaseState = releaseState ? [releaseState] : [];
          return [text, ...withReleaseState];
        }),
      ).toEqual([
        ['Model 1 (Mistral)', 'GA'],
        ['Model 4 (GPT)', 'GA'],
        ['Model 5 (Claude)', 'GA'],
        ['Model 2 (Code Llama)', 'BETA'],
        ['Model 3 (CodeGemma)', 'BETA'],
        ['GitLab AI vendor model'],
        ['Disabled'],
      ]);
    });

    describe('when showVendoredModelOption is false', () => {
      it('does not include vendored option in options list', () => {
        createComponent({
          injectedProps: {
            showVendoredModelOption: false,
          },
        });

        const modelOptions = findModelSelectDropdown().props('items');
        const vendoredOption = modelOptions.find((option) => option.value === PROVIDERS.VENDORED);
        expect(vendoredOption).toBeUndefined();
      });
    });
  });

  describe('when an update is saving', () => {
    it('updates the loading state', async () => {
      createComponent();

      await findModelSelectDropdown().vm.$emit('select', 'disabled');

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('when a batch update is saving', () => {
    it('updates the loading state', () => {
      createComponent({ props: { batchUpdateIsSaving: true } });

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    it.each`
      testCase               | selectedOption | provider                 | aiSelfHostedModelId
      ${'self-hosted model'} | ${1}           | ${PROVIDERS.SELF_HOSTED} | ${1}
      ${'disabled'}          | ${'disabled'}  | ${PROVIDERS.DISABLED}    | ${null}
      ${'vendored'}          | ${'vendored'}  | ${PROVIDERS.VENDORED}    | ${null}
    `(
      'with $testCase as selected option: calls the update mutation with the correct input',
      ({ selectedOption, provider, aiSelfHostedModelId }) => {
        const modelSelectDropdown = findModelSelectDropdown();
        modelSelectDropdown.vm.$emit('select', selectedOption);
        expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            features: ['CODE_GENERATIONS'],
            provider: provider.toUpperCase(),
            aiSelfHostedModelId,
          },
        });
      },
    );

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
      it('updates the selected option', async () => {
        const modelSelectDropdown = findModelSelectDropdown();

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          text: 'GitLab AI vendor model',
          value: PROVIDERS.VENDORED,
        });

        modelSelectDropdown.vm.$emit('select', 'disabled');
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            provider: PROVIDERS.DISABLED,
            selfHostedModel: null,
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          text: 'Disabled',
          value: PROVIDERS.DISABLED,
        });
      });
    });

    describe('when a model has been selected', () => {
      it('displays the selected deployment name and model', async () => {
        const selectedModel = mockSelfHostedModels[0];
        const modelSelectDropdown = findModelSelectDropdown();

        modelSelectDropdown.vm.$emit('select', selectedModel.id);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            provider: 'self_hosted',
            selfHostedModel: { id: selectedModel.id },
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          value: selectedModel.id,
          text: `${selectedModel.name} (${selectedModel.modelDisplayName})`,
          releaseState: selectedModel.releaseState,
        });
      });
    });
  });

  describe('when an update fails', () => {
    const selectedModel = mockSelfHostedModels[0];
    const updateFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettingUpdate: {
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
      expect(findModelSelectDropdown().props('selectedOption').value).toBe(PROVIDERS.VENDORED);
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

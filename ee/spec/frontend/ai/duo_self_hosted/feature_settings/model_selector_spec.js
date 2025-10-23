import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelector from 'ee/ai/duo_self_hosted/feature_settings/components/model_selector.vue';
import GitlabManagedModelsDisclaimerModal from 'ee/ai/duo_self_hosted/feature_settings/components/gitlab_managed_models_disclaimer_modal.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/ai/duo_self_hosted/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/ai/duo_self_hosted/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { PROVIDERS, GITLAB_DEFAULT_MODEL } from 'ee/ai/duo_self_hosted/feature_settings/constants';
import { SELF_HOSTED_ROUTE_NAMES } from 'ee/ai/duo_self_hosted/constants';
import { createAlert } from '~/alert';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import {
  mockSelfHostedModels,
  mockAiFeatureSettings,
  mockDuoAgentPlatformFeatureSettings,
  mockGitlabManagedModels,
  mockDefaultGitlabModel,
} from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

const EXPECTED_SELF_HOSTED_MODELS_OPTIONS = [
  {
    releaseState: 'GA',
    text: 'Model 1 (Mistral)',
    value: 'gid://gitlab/Ai::SelfHostedModel/1',
  },
  {
    releaseState: 'GA',
    text: 'Model 4 (GPT)',
    value: 'gid://gitlab/Ai::SelfHostedModel/4',
  },
  {
    releaseState: 'GA',
    text: 'Model 5 (Claude)',
    value: 'gid://gitlab/Ai::SelfHostedModel/5',
  },
  {
    releaseState: 'BETA',
    text: 'Model 2 (Code Llama)',
    value: 'gid://gitlab/Ai::SelfHostedModel/2',
  },
  {
    releaseState: 'BETA',
    text: 'Model 3 (CodeGemma)',
    value: 'gid://gitlab/Ai::SelfHostedModel/3',
  },
];

const EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS = [
  {
    text: 'Claude Sonnet 4.0 - Anthropic',
    value: 'claude_sonnet_4_20250514',
  },
  { text: 'Claude Sonnet 3.7 - Vertex', value: 'claude_sonnet_3_7_20250219_vertex' },
];

const EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS = {
  text: 'Self-hosted models',
  options: [
    ...EXPECTED_SELF_HOSTED_MODELS_OPTIONS,
    {
      text: 'Disabled',
      value: PROVIDERS.DISABLED,
    },
  ],
};

const EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS_WITH_VENDORED_OPTION = {
  text: 'Self-hosted models',
  options: [
    ...EXPECTED_SELF_HOSTED_MODELS_OPTIONS,
    {
      text: 'GitLab AI vendor model',
      value: PROVIDERS.VENDORED,
    },
    {
      text: 'Disabled',
      value: PROVIDERS.DISABLED,
    },
  ],
};

const EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS = {
  text: 'GitLab managed models',
  options: EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS,
};

const EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS_WITH_DEFAULT_MODEL_OPTION = {
  text: 'GitLab managed models',
  options: [
    ...EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS,
    { text: 'GitLab default model (Claude Sonnet 4.0 - Anthropic)', value: GITLAB_DEFAULT_MODEL },
  ],
};

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
  const mockShowModal = jest.fn();

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
          isDedicatedInstance: false,
          ...injectedProps,
        },
        propsData: {
          aiFeatureSetting: mockAiFeatureSetting,
          batchUpdateIsSaving: false,
          ...props,
        },
        stubs: {
          GitlabManagedModelsDisclaimerModal: stubComponent(GitlabManagedModelsDisclaimerModal, {
            methods: {
              showModal: mockShowModal,
            },
          }),
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
  const findVendoredModelOption = () => {
    const modelOptions = findModelSelectDropdown().props('items');
    return modelOptions.find((option) => option.value === PROVIDERS.VENDORED);
  };
  const findAddModelButton = () => wrapper.findByTestId('add-self-hosted-model-button');
  const findDisclaimerModal = () => wrapper.findComponent(GitlabManagedModelsDisclaimerModal);

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  it('renders compatible models header-text', () => {
    createComponent();

    expect(findModelSelectDropdown().props('headerText')).toBe('Compatible models');
  });

  describe('.listItems', () => {
    it('renders a button to add a self-hosted model', () => {
      createComponent();

      expect(findAddModelButton().text()).toBe('Add self-hosted model');
      expect(findAddModelButton().props('to')).toEqual({ name: SELF_HOSTED_ROUTE_NAMES.NEW });
    });

    describe('with Dedicated instance', () => {
      beforeEach(() => {
        createComponent({
          injectedProps: {
            isDedicatedInstance: true,
          },
        });
      });

      it('does not render model dropdown footer', () => {
        expect(findAddModelButton().exists()).toBe(false);
      });
    });
  });

  describe('for self-hosted models', () => {
    it('contains a list of options sorted by release state', () => {
      createComponent();

      const modelOptions = findModelSelectDropdown().props('items');
      const selfHostedModelsOptions = modelOptions[0].options;

      expect(
        selfHostedModelsOptions.map(({ text, releaseState }) => {
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

        expect(findVendoredModelOption()).toBeUndefined();
      });
    });

    describe('when feature is Duo Agent Platform', () => {
      it('does not include vendored option in options list', () => {
        createComponent({
          injectedProps: {
            showVendoredModelOption: true,
          },
          props: {
            aiFeatureSetting: mockDuoAgentPlatformFeatureSettings[0],
          },
        });

        expect(findVendoredModelOption()).toBeUndefined();
      });
    });
  });

  describe('with GitLab managed models', () => {
    it('renders two groups of options: self-hosted models and GitLab managed models', () => {
      createComponent({
        injectedProps: {
          showVendoredModelOption: false,
        },
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validGitlabModels: { nodes: mockGitlabManagedModels },
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([
        EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS,
        EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS,
      ]);
    });

    it('does not render self-hosted models if there are none returned', () => {
      createComponent({
        injectedProps: {
          showVendoredModelOption: false,
        },
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validModels: { nodes: [] },
            validGitlabModels: { nodes: mockGitlabManagedModels },
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS]);
    });

    it('renders default GitLab model under GitLab managed models group if it exists', () => {
      createComponent({
        injectedProps: {
          showVendoredModelOption: false,
        },
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validModels: { nodes: [] },
            validGitlabModels: { nodes: mockGitlabManagedModels },
            defaultGitlabModel: mockDefaultGitlabModel,
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([
        EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS_WITH_DEFAULT_MODEL_OPTION,
      ]);
    });

    it('does not render GitLab managed models group if there are none returned', () => {
      createComponent({
        injectedProps: {
          showVendoredModelOption: true,
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([
        EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS_WITH_VENDORED_OPTION,
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

    describe.each`
      testCase               | selectedOption                          | provider                 | selfHostedModelId                       | offeredModelRef
      ${'self-hosted model'} | ${'gid://gitlab/Ai::SelfHostedModel/1'} | ${PROVIDERS.SELF_HOSTED} | ${'gid://gitlab/Ai::SelfHostedModel/1'} | ${null}
      ${'disabled'}          | ${'disabled'}                           | ${PROVIDERS.DISABLED}    | ${null}                                 | ${null}
      ${'vendored'}          | ${'vendored'}                           | ${PROVIDERS.VENDORED}    | ${null}                                 | ${null}
    `(
      'with $testCase as selected option: calls the update mutation with the correct input',
      ({ selectedOption, provider, selfHostedModelId, offeredModelRef }) => {
        beforeEach(() => {
          const modelSelectDropdown = findModelSelectDropdown();
          modelSelectDropdown.vm.$emit('select', selectedOption);
        });

        it('calls the update mutation with the correct input', () => {
          expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['CODE_GENERATIONS'],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: selfHostedModelId,
              offeredModelRef,
            },
          });
        });

        it('does not call show disclaimer modal when selected', () => {
          expect(mockShowModal).not.toHaveBeenCalled();
        });
      },
    );

    describe.each`
      testCase                   | selectedOption                    | modelName                                                 | provider              | offeredModelRef
      ${'GitLab managed model'}  | ${mockGitlabManagedModels[0].ref} | ${mockGitlabManagedModels[0].name}                        | ${PROVIDERS.VENDORED} | ${mockGitlabManagedModels[0].ref}
      ${'GitlLab default model'} | ${GITLAB_DEFAULT_MODEL}           | ${'GitLab default model (Claude Sonnet 4.0 - Anthropic)'} | ${PROVIDERS.VENDORED} | ${GITLAB_DEFAULT_MODEL}
    `(
      'with $testCase as selected option',
      ({ selectedOption, modelName, provider, offeredModelRef }) => {
        beforeEach(() => {
          createComponent({
            props: {
              aiFeatureSetting: {
                ...mockAiFeatureSetting,
                validGitlabModels: { nodes: mockGitlabManagedModels },
                defaultGitlabModel: mockDefaultGitlabModel,
              },
            },
          });
          const modelSelectDropdown = findModelSelectDropdown();
          modelSelectDropdown.vm.$emit('select', selectedOption);
        });

        it('calls show disclaimer modal when selected', () => {
          expect(mockShowModal).toHaveBeenCalledTimes(1);
          expect(mockShowModal).toHaveBeenCalledWith({
            value: selectedOption,
            text: modelName,
          });
        });

        it('calls update operations when Gitlab managed model modal is acknowledged', async () => {
          findDisclaimerModal().vm.$emit('confirm', selectedOption);
          await waitForPromises();

          expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['CODE_GENERATIONS'],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: null,
              offeredModelRef,
            },
          });
          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
            'Successfully updated Code Suggestions / Code Generation',
          );
        });
      },
    );

    describe('when initial state is unassigned', () => {
      it('sets default GitLab model as the default when it is available', () => {
        createComponent({
          props: {
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.UNASSIGNED,
              defaultGitlabModel: mockDefaultGitlabModel,
              gitlabModel: mockDefaultGitlabModel,
            },
          },
        });

        const modelSelectDropdown = findModelSelectDropdown();
        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          text: `GitLab default model (Claude Sonnet 4.0 - Anthropic)`,
          value: GITLAB_DEFAULT_MODEL,
        });
      });

      it('does not set default GitLab model as the default when it is not available', () => {
        createComponent({
          props: {
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.UNASSIGNED,
              defaultGitlabModel: null,
              gitlabModel: null,
            },
          },
        });

        const modelSelectDropdown = findModelSelectDropdown();
        expect(modelSelectDropdown.props('selectedOption')).toEqual(null);
      });
    });

    it('triggers a success toast', async () => {
      findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated Code Suggestions / Code Generation',
      );
    });

    it('refreshes self-hosted models and feature settings data', async () => {
      findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

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
      it('for a self-hosted model: displays the selected deployment name and model', async () => {
        const selectedModel = mockSelfHostedModels[0];
        const modelSelectDropdown = findModelSelectDropdown();

        modelSelectDropdown.vm.$emit('select', selectedModel.id);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            provider: PROVIDERS.SELF_HOSTED,
            selfHostedModel: { id: selectedModel.id },
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          value: selectedModel.id,
          text: `${selectedModel.name} (${selectedModel.modelDisplayName})`,
          releaseState: selectedModel.releaseState,
        });
      });

      it('for a GitLab managed model: displays the selected deployment name and model', async () => {
        const selectedModel = mockGitlabManagedModels[0];
        const modelSelectDropdown = findModelSelectDropdown();

        modelSelectDropdown.vm.$emit('select', selectedModel.ref);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validGitlabModels: { nodes: mockGitlabManagedModels },
            provider: PROVIDERS.VENDORED,
            gitlabModel: { ref: selectedModel.ref },
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          value: selectedModel.ref,
          text: selectedModel.name,
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

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { createAlert } from '~/alert';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import GitlabDefaultModelModal from 'ee/ai/model_selection/gitlab_default_model_modal.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from 'ee/ai/model_selection/graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from 'ee/ai/model_selection/graphql/get_ai_namepace_feature_settings.query.graphql';
import {
  GITLAB_DEFAULT_MODEL,
  SUPPRESS_DEFAULT_MODEL_MODAL_KEY,
} from 'ee/ai/model_selection/constants';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

import { mockDuoChatFeatureSettings } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('ModelSelector', () => {
  let wrapper;

  const aiFeatureSetting = mockDuoChatFeatureSettings[0];
  const groupId = 'gid://gitlab/Group/1';
  const mockToastShow = jest.fn();
  const mockShowModal = jest.fn();

  const updateAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceUpdate: {
        errors: [],
      },
    },
  });

  const getAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceSettings: {
        nodes: mockDuoChatFeatureSettings,
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateAiNamespaceFeatureSettingsMutation, updateAiNamespaceFeatureSettingsSuccessHandler],
      [getAiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        apolloProvider: mockApollo,
        propsData: {
          aiFeatureSetting,
          batchUpdateIsSaving: false,
          ...props,
        },
        provide: {
          groupId,
        },
        stubs: {
          GitlabDefaultModelModal: stubComponent(GitlabDefaultModelModal, {
            methods: {
              showModal: mockShowModal,
            },
          }),
        },
        mocks: {
          $toast: {
            show: mockToastShow,
          },
        },
      }),
    );
  };

  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findDefaultModelModal = () => wrapper.findComponent(GitlabDefaultModelModal);

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
    expect(findDefaultModelModal().exists()).toBe(true);
  });

  describe('loading state', () => {
    it('passes correct loading state to `ModelSelectDropdown` while saving', async () => {
      createComponent();

      await findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });

    it('passes correct loading state to `ModelSelectDropdown` while batch saving', () => {
      createComponent({ props: { batchUpdateIsSaving: true } });

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('.listItems', () => {
    it('contains a default model', () => {
      createComponent();

      const items = findModelSelectDropdown().props('items');
      const defaultModel = items.find((item) => item.value === GITLAB_DEFAULT_MODEL);

      expect(defaultModel).toBeDefined();
    });

    it('sorts models in ascending alphabetical order', () => {
      const featureSettingWithUnsortedModels = {
        ...aiFeatureSetting,
        defaultModel: {
          name: 'Claude Sonnet 3.7',
          provider: 'Anthropic',
        },
        selectableModels: [
          { ref: 'claude_3_haiku_20240307', name: 'Claude Haiku 3', provider: 'Anthropic' },
          { ref: 'gpt_5', name: 'GPT-5', provider: 'OpenAI' },
          { ref: 'claude_sonnet_4_20250514', name: 'Claude Sonnet 4', provider: 'Anthropic' },
          { ref: 'claude_3_5_sonnet_20240620', name: 'Claude Sonnet 3.5', provider: 'Anthropic' },
          { ref: 'claude_sonnet_3_7_20250219', name: 'Claude Sonnet 3.7', provider: 'Anthropic' },
        ],
      };

      createComponent({ props: { aiFeatureSetting: featureSettingWithUnsortedModels } });

      const items = findModelSelectDropdown().props('items');
      const modelNames = items.map((item) => item.text);

      expect(modelNames).toStrictEqual([
        'Claude Haiku 3',
        'Claude Sonnet 3.5',
        'Claude Sonnet 3.7',
        'Claude Sonnet 4',
        'GPT-5',
        'Claude Sonnet 3.7 - Default',
      ]);
    });
  });

  describe('onSelect', () => {
    useLocalStorageSpy();

    beforeEach(() => {
      createComponent();
    });

    describe('when the GitLab default model is selected', () => {
      describe('when the modal has not been suppressed', () => {
        it('shows the modal and does not trigger `onUpdate`', async () => {
          const onUpdateSpy = jest.spyOn(wrapper.vm, 'onUpdate');

          await findModelSelectDropdown().vm.$emit('select', GITLAB_DEFAULT_MODEL);

          expect(mockShowModal).toHaveBeenCalled();
          expect(onUpdateSpy).not.toHaveBeenCalled();
        });
      });

      describe('when the modal has been suppressed', () => {
        beforeEach(() => {
          localStorage.setItem(SUPPRESS_DEFAULT_MODEL_MODAL_KEY, 'true');
        });

        it('does not show the modal and triggers `onUpdate`', async () => {
          const onUpdateSpy = jest.spyOn(wrapper.vm, 'onUpdate');

          await findModelSelectDropdown().vm.$emit('select', GITLAB_DEFAULT_MODEL);

          expect(mockShowModal).not.toHaveBeenCalled();
          expect(onUpdateSpy).toHaveBeenCalled();
        });
      });
    });

    describe('when any other model is selected', () => {
      it('does not show the modal and triggers `onUpdate`', async () => {
        const onUpdateSpy = jest.spyOn(wrapper.vm, 'onUpdate');

        await findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        expect(mockShowModal).not.toHaveBeenCalled();
        expect(onUpdateSpy).toHaveBeenCalled();
      });
    });
  });

  describe('onUpdate', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls the update mutation with correct input', () => {
      findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

      expect(updateAiNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
        input: {
          features: ['DUO_CHAT'],
          groupId: 'gid://gitlab/Group/1',
          offeredModelRef: 'claude_3_5_sonnet_20240620',
        },
      });
    });

    describe('when the update succeeds', () => {
      it('triggers a success toast', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated GitLab Duo Chat / General Chat',
        );
      });

      it('updates the selected option', async () => {
        const mockSelectedModelId = 'claude_3_5_sonnet_20240620';
        const modelSelectionDropdown = findModelSelectDropdown();

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: GITLAB_DEFAULT_MODEL,
          text: 'Claude Sonnet 3.7 - Default',
          provider: 'Anthropic',
          description: 'Fast, cost-effective responses.',
        });

        modelSelectionDropdown.vm.$emit('select', mockSelectedModelId);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...aiFeatureSetting,
            selectedModel: { ref: mockSelectedModelId },
          },
        });

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: mockSelectedModelId,
          text: 'Claude Sonnet 3.5',
          provider: 'Anthropic',
          description: 'Fast, cost-effective responses.',
        });
      });

      it('refetches namespace feature settings data', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(getAiNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalled();
      });
    });

    describe('when an update fails', () => {
      const updateAiNamespaceFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiModelSelectionNamespaceUpdate: {
            aiFeatureSettings: null,
            errors: ['Model selection not available'],
          },
        },
      });

      beforeEach(() => {
        createComponent({
          apolloHandlers: [
            [
              updateAiNamespaceFeatureSettingsMutation,
              updateAiNamespaceFeatureSettingsErrorHandler,
            ],
            [getAiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
          ],
        });
      });

      it('does not update the selected option', async () => {
        const modelSelectionDropdown = findModelSelectDropdown();

        modelSelectionDropdown.vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: GITLAB_DEFAULT_MODEL,
          text: 'Claude Sonnet 3.7 - Default',
          provider: 'Anthropic',
          description: 'Fast, cost-effective responses.',
        });
      });

      it('triggers an error message', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Model selection not available',
          }),
        );
      });
    });
  });
});

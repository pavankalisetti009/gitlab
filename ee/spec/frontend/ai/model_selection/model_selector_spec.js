import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from 'ee/ai/model_selection/graphql/update_ai_namespace_feature_settings.mutation.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { mockDuoChatFeatureSettings } from '../shared/feature_settings/mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('ModelSelector', () => {
  let wrapper;

  const aiFeatureSetting = mockDuoChatFeatureSettings[0];
  const groupId = 'gid://gitlab/Group/1';
  const updateAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceUpdate: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateAiNamespaceFeatureSettingsMutation, updateAiNamespaceFeatureSettingsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        apolloProvider: mockApollo,
        propsData: {
          aiFeatureSetting,
          ...props,
        },
        provide: {
          groupId,
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
  const findDropdownToggleText = () => findModelSelectDropdown().props('dropdownToggleText');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  describe('.listItems', () => {
    it('contains a list of models, including a default model option', () => {
      createComponent();

      expect(findModelSelectDropdown().props('items')).toEqual([
        { value: 'claude_sonnet_3_7_20250219', text: 'Claude Sonnet 3.7 - Anthropic' },
        { value: 'claude_3_5_sonnet_20240620', text: 'Claude Sonnet 3.5 - Anthropic' },
        { value: 'claude_3_haiku_20240307', text: 'Claude Haiku 3 - Anthropic' },
        { value: '', text: 'GitLab Default' },
      ]);
    });
  });

  describe('updating the feature setting', () => {
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

        expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
          'Successfully updated GitLab Duo Chat / General Chat',
        );
      });

      it('updates the dropdown toggle text', async () => {
        expect(findDropdownToggleText()).toBe('GitLab Default');

        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(findDropdownToggleText()).toBe('Claude Sonnet 3.5 - Anthropic');
      });
    });

    describe('when an update fails', () => {
      const updateAiNamespaceFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiModelSelectionNamespaceUpdate: {
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
          ],
        });
      });

      it('does not update the selected option', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(findModelSelectDropdown().props('dropdownToggleText')).toEqual('GitLab Default');
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

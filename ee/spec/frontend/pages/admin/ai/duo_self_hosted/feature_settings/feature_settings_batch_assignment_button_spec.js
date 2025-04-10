import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import FeatureSettingsBatchAssignmentButton from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/feature_settings_batch_assignment_button.vue';
import updateAiFeatureSettings from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import { mockDuoChatFeatureSettings } from './mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('FeatureSettingsBatchAssignmentButton', () => {
  let wrapper;

  const updateFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        aiFeatureSettings: mockDuoChatFeatureSettings,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[updateAiFeatureSettings, updateFeatureSettingsSuccessHandler]],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);
    const currentFeatureSetting = {
      ...mockDuoChatFeatureSettings[0],
      selfHostedModel: { id: 2 },
    };

    wrapper = mountExtended(FeatureSettingsBatchAssignmentButton, {
      apolloProvider: mockApollo,
      propsData: {
        currentFeatureSetting,
        aiFeatureSettings: mockDuoChatFeatureSettings,
        ...props,
      },
    });
  };

  const findBatchAssignmentButton = () => wrapper.findByTestId('model-batch-assignment-button');
  const findBatchAssignmentTooltip = () => wrapper.findByTestId('model-batch-assignment-tooltip');

  it('renders a button to batch assign an option for all sub-features', () => {
    createComponent();

    const tooltipText = 'Apply to all GitLab Duo Chat sub-features';

    expect(findBatchAssignmentTooltip().attributes('title')).toBe(tooltipText);
    expect(findBatchAssignmentButton().attributes('aria-label')).toBe(tooltipText);
  });

  describe('when the current feature setting has no option assigned', () => {
    it('disables the batch update button', () => {
      const currentFeatureSetting = {
        feature: 'duo_chat',
        title: 'General Chat',
        provider: 'vendored',
      };

      createComponent({ props: { currentFeatureSetting } });

      expect(findBatchAssignmentButton().props('disabled')).toBe(true);
      expect(findBatchAssignmentTooltip().attributes('title')).toBe(
        'Assign a setting to the General Chat sub-feature before applying to all',
      );
    });
  });

  describe('batch updates', () => {
    describe('when the update succeeds', () => {
      describe('updating feature settings with models', () => {
        beforeEach(async () => {
          createComponent();

          await findBatchAssignmentButton().trigger('click');
          await waitForPromises();
        });

        it('invokes the update mutation with correct input', () => {
          expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['DUO_CHAT', 'DUO_CHAT_EXPLAIN_CODE'],
              provider: 'SELF_HOSTED',
              aiSelfHostedModelId: 2,
            },
          });
        });

        it('emits update event with updated feature settings', () => {
          expect(wrapper.emitted('update-feature-settings')[0][0]).toEqual(
            mockDuoChatFeatureSettings,
          );
        });

        it('emits events to update loading state on parent', () => {
          expect(wrapper.emitted('update-batch-saving-state')).toHaveLength(2);
        });
      });

      describe('batch disabling feature settings', () => {
        const mockDisabledDuoChatFeatureSettings = mockDuoChatFeatureSettings.map((setting) => ({
          ...setting,
          provider: 'disabled',
        }));
        const currentFeatureSetting = {
          provider: 'disabled',
          selfHostedModel: null,
        };
        const disableFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
          data: {
            aiFeatureSettingUpdate: {
              aiFeatureSettings: mockDisabledDuoChatFeatureSettings,
              errors: [],
            },
          },
        });

        beforeEach(async () => {
          createComponent({
            apolloHandlers: [[updateAiFeatureSettings, disableFeatureSettingsSuccessHandler]],
            props: { currentFeatureSetting },
          });

          await findBatchAssignmentButton().trigger('click');
          await waitForPromises();
        });

        it('invokes the update mutation with correct input', () => {
          expect(disableFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['DUO_CHAT', 'DUO_CHAT_EXPLAIN_CODE'],
              provider: 'DISABLED',
              aiSelfHostedModelId: null,
            },
          });
        });

        it('emits an update-feature-settings event with the updated feature settings', () => {
          expect(wrapper.emitted('update-feature-settings')[0][0]).toEqual(
            mockDisabledDuoChatFeatureSettings,
          );
        });

        it('emits events to update loading state on parent', () => {
          expect(wrapper.emitted('update-batch-saving-state')).toHaveLength(2);
        });
      });
    });

    describe('when the update does not succeed', () => {
      describe('due to a general error', () => {
        it('displays an error message', async () => {
          createComponent({
            apolloHandlers: [[updateAiFeatureSettings, jest.fn().mockRejectedValue('ERROR')]],
          });

          await findBatchAssignmentButton().trigger('click');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the GitLab Duo Chat sub-feature settings. Please try again.',
            }),
          );
        });
      });

      describe('due to a business logic error', () => {
        const updateAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
          data: {
            aiFeatureSettings: {
              errors: ['An error occured'],
            },
          },
        });

        it('displays an error message', async () => {
          createComponent({
            apolloHandlers: [[updateAiFeatureSettings, updateAiFeatureSettingsErrorHandler]],
          });

          await findBatchAssignmentButton().trigger('click');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the GitLab Duo Chat sub-feature settings. Please try again.',
            }),
          );
        });
      });
    });
  });
});

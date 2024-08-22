import { shallowMount } from '@vue/test-utils';
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

jest.mock('ee/api/groups_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

let wrapper;

const createComponent = (props = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      redirectPath: '/groups/test-group',
      updateId: '100',
      ...props,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);

describe('AiGroupSettings', () => {
  beforeEach(() => {
    createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });
  });

  describe('updateSettings', () => {
    it('calls updateGroupSettings with correct parameters', async () => {
      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
      });
      expect(updateGroupSettings).toHaveBeenCalledTimes(1);
      expect(updateGroupSettings).toHaveBeenCalledWith('100', {
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experiment_features_enabled: true,
      });
    });

    it('shows success message on successful update', async () => {
      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
      });
      await waitForPromises();
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Group was successfully updated.',
          }),
        ]),
      );
    });

    it('shows error message on failed update', async () => {
      const error = new Error('API error');
      updateGroupSettings.mockRejectedValue(error);
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
      });
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message:
            'An error occurred while retrieving your settings. Reload the page to try again.',
          error,
        }),
      );
    });
  });
});

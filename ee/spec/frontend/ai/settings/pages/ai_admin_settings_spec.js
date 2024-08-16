import { shallowMount } from '@vue/test-utils';
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

jest.mock('~/rest_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

let wrapper;

const createComponent = (props = {}) => {
  wrapper = shallowMount(AiAdminSettings, {
    propsData: {
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      redirectPath: '/admin/application_settings',
      ...props,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);

describe('AiAdminSettings', () => {
  beforeEach(() => {
    createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('passes correct props to AiCommonSettings', () => {
      expect(findAiCommonSettings().props()).toEqual({
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        areDuoSettingsLocked: false,
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateApplicationSettings with correct params', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      });
      expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      });
    });

    it('shows success message on successful update', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      });
      await waitForPromises();
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Application settings saved successfully.',
          }),
        ]),
      );
    });

    it('shows error message on failed update', async () => {
      const error = new Error('Update failed');
      updateApplicationSettings.mockRejectedValue(error);
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
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

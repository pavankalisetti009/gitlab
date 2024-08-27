import { shallowMount } from '@vue/test-utils';
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import CodeSuggestionsConnectionForm from 'ee/ai/settings/components/code_suggestions_connection_form.vue';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

jest.mock('~/rest_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

let wrapper;

const createComponent = (props = {}, provide = {}) => {
  wrapper = shallowMount(AiAdminSettings, {
    propsData: {
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      redirectPath: '/admin/application_settings',
      duoProVisible: true,
      ...props,
    },
    provide: {
      disabledDirectConnectionMethod: false,
      ...provide,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findCodeSuggestionsConnectionForm = () =>
  wrapper.findComponent(CodeSuggestionsConnectionForm);

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
        hasParentFormChanged: false,
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateApplicationSettings with correct params', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
      });
      expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        instance_level_ai_beta_features_enabled: false,
        disabled_direct_code_suggestions: false,
      });
    });

    it('shows success message on successful update', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
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

  describe('when duoProVisible', () => {
    it('is availabile it does display the connection form', () => {
      createComponent({ duoProVisible: true });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(true);
    });

    it('is not availabile it does not display the connection form', () => {
      createComponent({ duoProVisible: false });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(false);
    });
  });

  describe('onConnectionFormChange', () => {
    beforeEach(() => {
      createComponent({ duoProVisible: true });
    });

    it('sets hasParentFormChanged to true when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', true);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('sets hasParentFormChanged to false when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', false);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });
});

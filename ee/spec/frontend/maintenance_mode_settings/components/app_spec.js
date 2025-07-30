import { GlToggle, GlFormTextarea, GlForm, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import MaintenanceModeSettingsApp from 'ee/maintenance_mode_settings/components/app.vue';
import { updateApplicationSettings } from '~/rest_api';
import { createAlert } from '~/alert';

jest.mock('~/rest_api.js');
jest.mock('~/alert');

describe('MaintenanceModeSettingsApp', () => {
  let wrapper;

  const defaultProps = {
    initialBannerMessage: '',
    initialMaintenanceEnabled: false,
  };

  const createComponent = (props) => {
    wrapper = shallowMount(MaintenanceModeSettingsApp, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findMaintenanceModeSettingsForm = () => wrapper.findComponent(GlForm);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGlToggle = () => wrapper.findComponent(GlToggle);
  const findGlFormTextarea = () => wrapper.findComponent(GlFormTextarea);

  describe('when maintenance mode is enabled', () => {
    beforeEach(() => {
      createComponent({
        initialBannerMessage: 'test message',
        initialMaintenanceEnabled: true,
      });
    });

    it('renders the form and not loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
      expect(findMaintenanceModeSettingsForm().exists()).toBe(true);
    });

    it('sets the GlToggle to true', () => {
      expect(findGlToggle().attributes('value')).toBe('true');
    });

    it('sets the GlFormTextarea to the banner message', () => {
      expect(findGlFormTextarea().attributes('value')).toBe('test message');
    });

    it('properly calls updateApplicationSettings when the form is updated and submitted', async () => {
      findGlToggle().vm.$emit('change', false);
      findGlFormTextarea().vm.$emit('input', '');
      await nextTick();

      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        maintenance_mode: false,
        maintenance_mode_message: '',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when maintenance mode is disabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form and not loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
      expect(findMaintenanceModeSettingsForm().exists()).toBe(true);
    });

    it('sets the GlToggle to undefined', () => {
      expect(findGlToggle().attributes('value')).toBeUndefined();
    });

    it('sets the GlFormTextarea to be empty', () => {
      expect(findGlFormTextarea().attributes('value')).toBe('');
    });

    it('properly calls updateApplicationSettings when the form is updated and submitted', async () => {
      findGlToggle().vm.$emit('change', true);
      findGlFormTextarea().vm.$emit('input', 'test message');
      await nextTick();

      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        maintenance_mode: true,
        maintenance_mode_message: 'test message',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when updating maintenance mode fails', () => {
    beforeEach(() => {
      updateApplicationSettings.mockImplementation(() => Promise.reject());
      createComponent();
    });

    it('sends a createAlert error', async () => {
      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error updating the Maintenance Mode Settings',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });
});

import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import WarnModeBanner from 'ee/security_orchestration/components/policies/banners/warn_mode_banner.vue';

describe('WarnModeBanner', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WarnModeBanner, {
      propsData: props,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlAlert when not dismissed', () => {
      const alert = findAlert();

      expect(alert.exists()).toBe(true);
      expect(alert.props()).toMatchObject({
        dismissible: true,
        title: "We've added something new!",
      });

      expect(alert.text()).toContain('Learn more');
    });
  });

  describe('alert interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('dismisses alert when dismiss event is emitted', async () => {
      const alert = findAlert();

      expect(alert.exists()).toBe(true);

      alert.vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('LocalStorageSync integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes correct initial value to LocalStorageSync', () => {
      expect(findLocalStorageSync().props('value')).toBe(false);
    });

    it('syncs state when alert is dismissed via dismiss button', async () => {
      const alert = findAlert();
      const localStorageSync = findLocalStorageSync();

      // Initially not dismissed
      expect(localStorageSync.props('value')).toBe(false);

      // Dismiss the alert via button
      alert.vm.$emit('dismiss');
      await nextTick();

      expect(localStorageSync.props('value')).toBe(true);
    });
  });
});

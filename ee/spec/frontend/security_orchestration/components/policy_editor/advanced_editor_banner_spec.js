import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AdvancedEditorBanner from 'ee/security_orchestration/components/policy_editor/advanced_editor_banner.vue';
import { ADVANCED_EDITOR_DISMISS_STORAGE_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('AdvancedEditorBanner', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AdvancedEditorBanner, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders LocalStorageSync with correct props', () => {
      const localStorageSync = findLocalStorageSync();

      expect(localStorageSync.exists()).toBe(true);
      expect(localStorageSync.props('storageKey')).toBe(ADVANCED_EDITOR_DISMISS_STORAGE_KEY);
    });

    it('renders alert when not dismissed', () => {
      const alert = findAlert();

      expect(alert.exists()).toBe(true);
      expect(alert.props()).toMatchObject({
        secondaryButtonText: "Don't show again",
        variant: 'tip',
      });
    });

    it('renders formatted banner content with GlSprintf', () => {
      expect(findAlert().text()).toBe(
        'Experiment: Try our new advanced policy editor for a more intuitive experience.',
      );
    });
  });

  describe('alert visibility', () => {
    it('shows alert when alertDismissed is false', () => {
      createComponent();

      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('dismiss banner', () => {
      it('hides alert when alertDismissed is true', async () => {
        expect(findAlert().exists()).toBe(true);

        await findAlert().vm.$emit('secondaryAction');

        expect(findAlert().exists()).toBe(false);
      });
    });
  });
});

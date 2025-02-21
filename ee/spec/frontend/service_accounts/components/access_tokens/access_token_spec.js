import { GlAlert } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import AccessToken from 'ee/service_accounts/components/access_tokens/access_token.vue';
import { useAccessTokens } from 'ee/service_accounts/stores/access_tokens';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';

Vue.use(PiniaVuePlugin);

describe('AccessToken', () => {
  let wrapper;

  const pinia = createTestingPinia();
  const store = useAccessTokens();

  const createComponent = () => {
    wrapper = shallowMountExtended(AccessToken, {
      pinia,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findInputCopyToggleVisibility = () => wrapper.findComponent(InputCopyToggleVisibility);

  describe('when token is null', () => {
    it('hides the alert', () => {
      createComponent();
      expect(findAlert().exists()).toBe(false);
      expect(findInputCopyToggleVisibility().exists()).toBe(false);
    });
  });

  describe('when token is present', () => {
    beforeEach(() => {
      store.token = 'my-token';
      createComponent();
    });

    it('renders the alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findInputCopyToggleVisibility().props()).toMatchObject({
        copyButtonTitle: 'Copy token',
        formInputGroupProps: {
          'data-testid': 'access-token-field',
          id: 'access-token-field',
          name: 'access-token-field',
        },
        initialVisibility: false,
        readonly: true,
        showCopyButton: true,
        showToggleVisibilityButton: true,
        size: 'lg',
        value: 'my-token',
      });
    });

    it('nullifies token if alert is dismissed', () => {
      findAlert().vm.$emit('dismiss');
      expect(store.setToken).toHaveBeenCalledWith(null);
    });
  });
});

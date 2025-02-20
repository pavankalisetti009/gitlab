import { GlFilteredSearch, GlPagination } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import AccessTokens from 'ee/service_accounts/components/access_tokens/access_tokens.vue';
import { useAccessTokens } from 'ee/service_accounts/stores/access_tokens';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(PiniaVuePlugin);

describe('AccessTokens', () => {
  let wrapper;

  const pinia = createTestingPinia();
  const store = useAccessTokens();

  const accessTokenShow = 'https://gitlab.example.com/api/v4/personal_access_tokens';
  const id = 235;

  const createComponent = () => {
    wrapper = shallowMountExtended(AccessTokens, {
      pinia,
      provide: {
        accessTokenShow,
      },
      propsData: {
        id,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPagination = () => wrapper.findComponent(GlPagination);

  it('fetches tokens when it is rendered', () => {
    createComponent();
    waitForPromises();

    expect(store.setup).toHaveBeenCalledWith({
      filters: [{ type: 'state', value: { data: 'active', operator: '=' } }],
      id: 235,
      urlShow: 'https://gitlab.example.com/api/v4/personal_access_tokens',
    });
    expect(store.fetchTokens).toHaveBeenCalledTimes(1);
  });

  it('fetches tokens when the page is changed', () => {
    createComponent();
    expect(store.fetchTokens).toHaveBeenCalledTimes(1);
    findPagination().vm.$emit('input', 2);

    expect(store.fetchTokens).toHaveBeenCalledTimes(2);
  });

  it('fetches tokens when filters are changed', () => {
    createComponent();
    expect(store.fetchTokens).toHaveBeenCalledTimes(1);
    findFilteredSearch().vm.$emit('submit', ['my token']);

    expect(store.fetchTokens).toHaveBeenCalledTimes(2);
  });
});

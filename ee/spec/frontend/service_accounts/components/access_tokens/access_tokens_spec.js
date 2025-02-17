import { GlFilteredSearch, GlPagination } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import AccessTokens from 'ee/service_accounts/components/access_tokens/access_tokens.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import { pinia } from '~/pinia/instance';

describe('AccessTokens', () => {
  let wrapper;
  const mockAxios = new MockAdapter(axios);
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

  beforeEach(() => {
    mockAxios.reset();
  });

  it('fetches tokens when it is rendered', async () => {
    createComponent();
    await waitForPromises();

    expect(mockAxios.history.get).toHaveLength(1);
    expect(mockAxios.history.get[0]).toEqual(
      expect.objectContaining({
        url: accessTokenShow,
        params: {
          page: 1,
          state: 'active',
          sort: 'expires_at_asc_id_desc',
          user_id: 235,
        },
      }),
    );
  });

  it('fetches tokens when the page is changed', async () => {
    createComponent();
    findPagination().vm.$emit('input', 2);
    await waitForPromises();

    expect(mockAxios.history.get).toHaveLength(2);
    expect(mockAxios.history.get[1]).toEqual(
      expect.objectContaining({
        url: accessTokenShow,
        params: {
          page: 2,
          state: 'active',
          sort: 'expires_at_asc_id_desc',
          user_id: 235,
        },
      }),
    );
  });

  it('fetches tokens when filters are changed', async () => {
    createComponent();
    findFilteredSearch().vm.$emit('submit', ['my token']);
    await waitForPromises();

    expect(mockAxios.history.get).toHaveLength(2);
    expect(mockAxios.history.get[1]).toEqual(
      expect.objectContaining({
        url: accessTokenShow,
        params: {
          page: 1,
          sort: 'expires_at_asc_id_desc',
          search: 'my token',
          user_id: 235,
        },
      }),
    );
  });
});

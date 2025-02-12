import MockAdapter from 'axios-mock-adapter';
import { setActivePinia, createPinia } from 'pinia';

import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import { useServiceAccounts } from 'ee/service_accounts/stores/service_accounts';

jest.mock('~/alert');

describe('useAccessTokens store', () => {
  let store;
  const mockAxios = new MockAdapter(axios);
  const url = 'https://gitlab.example.com/api/v4/groups/33/service_accounts';
  const params = { page: 1, perPage: 8 };
  const headers = {
    'X-Page': 1,
    'X-Per-Page': 8,
    'X-Total': 1,
  };

  mockAxios
    .onGet(url, {
      params: { page: 1, per_page: 8, orderBy: 'name' },
    })
    .reply(
      HTTP_STATUS_OK,
      [
        {
          id: 85,
          username: 'service_account_group_33_71573d686886d1e49b90c9705f4f534b',
          name: 'Service account user',
        },
      ],
      headers,
    );

  beforeEach(() => {
    setActivePinia(createPinia());
    store = useServiceAccounts();
  });

  describe('initial state', () => {
    it('has an empty list of service accounts', () => {
      expect(store.serviceAccounts).toEqual([]);
    });

    it('is not busy', () => {
      expect(store.busy).toBe(false);
    });
  });

  describe('actions', () => {
    describe('fetchServiceAccounts', () => {
      it('sets busy to true when fetching', () => {
        store.fetchServiceAccounts(url, params);
        expect(store.busy).toBe(true);
      });

      it('updates service accounts after fetching', async () => {
        await store.fetchServiceAccounts(url, params);

        expect(store.serviceAccounts).toHaveLength(1);
        expect(store.busy).toBe(false);
      });

      it('shows an alert if an error occurs while fetching', async () => {
        mockAxios.reset();
        mockAxios.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await store.fetchServiceAccounts(url, params);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while fetching the service accounts.',
        });
        expect(store.busy).toBe(false);
      });
    });
  });
});

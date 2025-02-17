import MockAdapter from 'axios-mock-adapter';
import { setActivePinia, createPinia } from 'pinia';
import { useAccessTokens } from 'ee/service_accounts/stores/access_tokens';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';

jest.mock('~/alert');

describe('useAccessTokens store', () => {
  let store;

  beforeEach(() => {
    setActivePinia(createPinia());
    store = useAccessTokens();
  });

  describe('initial state', () => {
    it('has an empty list of access tokens', () => {
      expect(store.alert).toBe(null);
      expect(store.busy).toBe(false);
      expect(store.filters).toEqual([]);
      expect(store.id).toBe(null);
      expect(store.page).toBe(1);
      expect(store.perPage).toBe(null);
      expect(store.tokens).toEqual([]);
      expect(store.total).toBe(0);
      expect(store.urlShow).toBe('');
    });
  });

  describe('actions', () => {
    const mockAxios = new MockAdapter(axios);
    const urlShow = 'https://gitlab.example.com/api/v4/personal_access_tokens';
    const id = 235;
    const filters = ['dummy'];
    const headers = {
      'X-Page': 1,
      'X-Per-Page': 20,
      'X-Total': 1,
    };

    beforeEach(() => {
      mockAxios.reset();
    });

    describe('setup', () => {
      it('sets up the store', async () => {
        await store.setup({ id, filters, urlShow });

        expect(store.id).toBe(id);
        expect(store.filters).toEqual(filters);
        expect(store.urlShow).toBe(urlShow);
      });
    });

    describe('fetchAccessTokens', () => {
      beforeEach(() => {
        store.setup({ id, filters, urlShow });
      });

      it('sets busy to true when fetching', () => {
        store.fetchTokens();

        expect(store.busy).toBe(true);
      });

      it('updates tokens and sets busy to false after fetching', async () => {
        mockAxios.onGet(urlShow).reply(HTTP_STATUS_OK, [{ active: true, name: 'Token' }], headers);
        await store.fetchTokens();

        expect(store.tokens).toHaveLength(1);
        expect(store.busy).toBe(false);
      });

      it('shows an alert if an error occurs while fetching', async () => {
        mockAxios.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await store.fetchTokens();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while fetching the tokens.',
        });
        expect(store.busy).toBe(false);
      });

      it('uses correct params in the fetch', async () => {
        store.setFilters([
          'my token',
          {
            type: 'created',
            value: { data: '2025-01-01', operator: '<' },
          },
          {
            type: 'expires',
            value: { data: '2025-01-01', operator: '<' },
          },
          {
            type: 'last_used',
            value: { data: '2025-01-01', operator: '≥' },
          },
          {
            type: 'state',
            value: { data: 'inactive', operator: '=' },
          },
        ]);
        await store.fetchTokens();

        expect(mockAxios.history.get).toHaveLength(1);
        expect(mockAxios.history.get[0]).toEqual(
          expect.objectContaining({
            url: urlShow,
            params: {
              created_before: '2025-01-01',
              expires_before: '2025-01-01',
              last_used_after: '2025-01-01',
              page: 1,
              sort: 'expires_at_asc_id_desc',
              state: 'inactive',
              search: 'my token',
              user_id: 235,
            },
          }),
        );
      });
    });

    describe('setPage', () => {
      it('sets the page', () => {
        store.setPage(2);

        expect(store.page).toBe(2);
      });
    });
  });
});

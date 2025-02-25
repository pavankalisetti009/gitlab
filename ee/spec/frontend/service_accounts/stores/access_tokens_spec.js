import MockAdapter from 'axios-mock-adapter';
import { setActivePinia, createPinia } from 'pinia';
import { useAccessTokens } from 'ee/service_accounts/stores/access_tokens';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_NO_CONTENT,
  HTTP_STATUS_OK,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
} from '~/lib/utils/http_status';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

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
      expect(store.token).toEqual(null);
      expect(store.tokens).toEqual([]);
      expect(store.total).toBe(0);
      expect(store.urlRotate).toBe('');
      expect(store.urlShow).toBe('');
    });
  });

  describe('actions', () => {
    const mockAxios = new MockAdapter(axios);
    const filters = ['dummy'];
    const id = 235;
    const urlRotate = '/api/v4/groups/4/service_accounts/:id/personal_access_tokens';
    const urlShow = '/api/v4/personal_access_tokens';

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
        await store.setup({ filters, id, urlRotate, urlShow });

        expect(store.filters).toEqual(filters);
        expect(store.id).toBe(id);
        expect(store.urlRotate).toBe(urlRotate);
        expect(store.urlShow).toBe(urlShow);
      });
    });

    describe('fetchTokens', () => {
      beforeEach(() => {
        store.setup({ id, filters, urlShow });
      });

      it('sets busy to true when fetching', () => {
        store.fetchTokens();

        expect(store.busy).toBe(true);
      });

      it('dismisses any existing alert by default', () => {
        store.alert = createAlert({ message: 'dummy' });
        store.fetchTokens();

        expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
      });

      it('does not dismiss existing alert if clearAlert is false', () => {
        store.alert = createAlert({ message: 'dummy' });
        store.fetchTokens({ clearAlert: false });

        expect(mockAlertDismiss).toHaveBeenCalledTimes(0);
      });

      it('updates tokens and sets busy to false after fetching', async () => {
        mockAxios
          .onGet(urlShow)
          .replyOnce(HTTP_STATUS_OK, [{ active: true, name: 'Token' }], headers);
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

    describe('rotateToken', () => {
      beforeEach(() => {
        store.setup({ id, filters, urlRotate });
      });

      it('sets busy to true when rotating', () => {
        store.rotateToken(1, '2025-01-01');

        expect(store.busy).toBe(true);
      });

      it('dismisses any existing alert', () => {
        store.alert = createAlert({ message: 'dummy' });
        store.fetchTokens();

        expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
      });

      it('rotates the token', async () => {
        await store.rotateToken(1, '2025-01-01');

        expect(mockAxios.history.post).toHaveLength(1);
        expect(mockAxios.history.post[0]).toEqual(
          expect.objectContaining({
            url: '/api/v4/groups/4/service_accounts/235/personal_access_tokens/1/rotate',
            data: '{"expires_at":"2025-01-01"}',
          }),
        );
      });

      it('scrolls to the top', async () => {
        const scrollToSpy = jest.spyOn(window, 'scrollTo');
        mockAxios.onPost().replyOnce(HTTP_STATUS_NO_CONTENT);
        await store.rotateToken(1, '2025-01-01');

        expect(scrollToSpy).toHaveBeenCalledWith({ top: 0, behavior: 'smooth' });
      });

      it('updates tokens and sets busy to false after fetching', async () => {
        mockAxios.onPost().replyOnce(HTTP_STATUS_NO_CONTENT);
        mockAxios.onGet().replyOnce(HTTP_STATUS_OK, [{ active: true, name: 'Token' }], headers);
        await store.rotateToken(1, '2025-01-01');

        expect(store.tokens).toHaveLength(1);
        expect(store.busy).toBe(false);
      });

      it('shows an alert if an error occurs while rotating', async () => {
        mockAxios.onPost().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        await store.rotateToken(1, '2025-01-01');

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while rotating the token.',
        });
        expect(store.busy).toBe(false);
      });

      it('shows an alert if an error occurs while fetching', async () => {
        mockAxios.onPost().replyOnce(HTTP_STATUS_NO_CONTENT);
        mockAxios.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        await store.rotateToken(1, '2025-01-01');

        expect(createAlert).toHaveBeenCalledTimes(2);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while fetching the tokens.',
        });
        expect(store.busy).toBe(false);
      });

      it('uses correct params in the fetch', async () => {
        mockAxios.onPost().replyOnce(HTTP_STATUS_NO_CONTENT);
        mockAxios.onGet().replyOnce(HTTP_STATUS_OK, [{ active: true, name: 'Token' }], headers);
        store.setPage(2);
        store.setFilters(['my token']);
        await store.rotateToken(1, '2025-01-01');

        expect(mockAxios.history.get).toHaveLength(1);
        expect(mockAxios.history.get[0]).toEqual(
          expect.objectContaining({
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

    describe('setPage', () => {
      it('sets the page', () => {
        store.setPage(2);

        expect(store.page).toBe(2);
      });

      it('scrolls to the top', () => {
        const scrollToSpy = jest.spyOn(window, 'scrollTo');
        store.setPage(2);

        expect(scrollToSpy).toHaveBeenCalledWith({ top: 0, behavior: 'smooth' });
      });
    });

    describe('setToken', () => {
      it('sets the token', () => {
        store.setToken(2);

        expect(store.token).toBe(2);
      });
    });
  });
});

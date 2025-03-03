import { defineStore } from 'pinia';
import { createAlert } from '~/alert';
import { smoothScrollTop } from '~/behaviors/smooth_scroll';
import axios from '~/lib/utils/axios_utils';
import {
  convertObjectPropsToCamelCase,
  normalizeHeaders,
  parseIntPagination,
} from '~/lib/utils/common_utils';
import { s__ } from '~/locale';
import { SORT_OPTIONS, DEFAULT_SORT } from '~/access_tokens/constants';

/**
 * Fetch access tokens
 *
 * @param {string} url
 * @param {string|number} id
 * @param {Object<string, string|number>} params
 * @param {string} sort
 */
const fetchTokens = async ({ url, id, params, sort }) => {
  const { data, headers } = await axios.get(url, {
    params: { user_id: id, sort, ...params },
  });
  const { perPage, total } = parseIntPagination(normalizeHeaders(headers));

  return { data, perPage, total };
};

export const useAccessTokens = defineStore('accessTokens', {
  state() {
    return {
      alert: null,
      busy: false,
      filters: [],
      id: null,
      page: 1,
      perPage: null,
      token: null, // New and rotated token
      tokens: [],
      total: 0,
      urlRevoke: '',
      urlRotate: '',
      urlShow: '',
      sorting: DEFAULT_SORT,
    };
  },
  actions: {
    async fetchTokens({ clearAlert } = { clearAlert: true }) {
      if (clearAlert) {
        this.alert?.dismiss();
      }
      this.busy = true;
      try {
        const { data, perPage, total } = await fetchTokens({
          url: this.urlShow,
          id: this.id,
          params: this.params,
          sort: this.sort,
        });
        this.tokens = convertObjectPropsToCamelCase(data, { deep: true });
        this.perPage = perPage;
        this.total = total;
      } catch {
        this.alert = createAlert({
          message: s__('AccessTokens|An error occurred while fetching the tokens.'),
        });
      } finally {
        this.busy = false;
      }
    },
    async revokeToken(tokenId) {
      this.alert?.dismiss();
      this.busy = true;
      try {
        const url = this.urlRevoke.replace(':id', this.id);
        await axios.delete(`${url}/${tokenId}`);
        this.alert = createAlert({
          message: s__('AccessTokens|The token was revoked successfully.'),
          variant: 'success',
        });
        smoothScrollTop();
        // Reset pagination to avoid situations like: page 2 contains only one token and after it
        // is revoked the page shows `No tokens access tokens` (but there are 20 tokens on page 1).
        this.page = 1;
        await this.fetchTokens({ clearAlert: false });
      } catch {
        this.alert = createAlert({
          message: s__('AccessTokens|An error occurred while revoking the token.'),
        });
      } finally {
        this.busy = false;
      }
    },
    async rotateToken(tokenId, expiresAt) {
      this.alert?.dismiss();
      this.busy = true;
      try {
        const url = this.urlRotate.replace(':id', this.id);
        const { data } = await axios.post(`${url}/${tokenId}/rotate`, { expires_at: expiresAt });
        smoothScrollTop();
        // Reset pagination because after rotation the token may appear on a different page.
        this.page = 1;
        await this.fetchTokens({ clearAlert: false });
        this.token = data.token;
      } catch (error) {
        const message =
          error?.response?.data?.message ??
          s__('AccessTokens|An error occurred while rotating the token.');
        this.alert = createAlert({ message });
      } finally {
        this.busy = false;
      }
    },
    setup({ filters, id, urlRevoke, urlRotate, urlShow }) {
      this.filters = filters;
      this.id = id;
      this.urlRevoke = urlRevoke;
      this.urlRotate = urlRotate;
      this.urlShow = urlShow;
    },
    setFilters(filters) {
      this.filters = filters;
    },
    setPage(page) {
      smoothScrollTop();
      this.page = page;
    },
    setToken(token) {
      this.token = token;
    },
    setSorting(sorting) {
      this.sorting = sorting;
    },
  },
  getters: {
    params() {
      const newParams = { page: this.page };

      this.filters?.forEach((token) => {
        if (typeof token === 'string') {
          newParams.search = token;
        } else if (['created', 'expires', 'last_used'].includes(token.type)) {
          const isBefore = token.value.operator === '<';
          const key = `${token.type}${isBefore ? '_before' : '_after'}`;
          newParams[key] = token.value.data;
        } else {
          newParams[token.type] = token.value.data;
        }
      });

      return newParams;
    },
    sort() {
      const { value, isAsc } = this.sorting;
      const sortOption = SORT_OPTIONS.find((option) => option.value === value);

      return isAsc ? sortOption.sort.asc : sortOption.sort.desc;
    },
  },
});

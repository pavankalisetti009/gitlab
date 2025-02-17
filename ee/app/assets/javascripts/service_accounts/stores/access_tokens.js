import { defineStore } from 'pinia';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  convertObjectPropsToCamelCase,
  normalizeHeaders,
  parseIntPagination,
} from '~/lib/utils/common_utils';
import { s__ } from '~/locale';

/**
 * Fetch access tokens
 *
 * @param {string} url
 * @param {string|number} id
 * @param {Object<string, string|number>} params
 */
const fetchTokens = async (url, id, params) => {
  const { data, headers } = await axios.get(url, {
    params: { user_id: id, sort: 'expires_at_asc_id_desc', ...params },
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
      tokens: [],
      total: 0,
      urlShow: '',
    };
  },
  actions: {
    async fetchTokens() {
      this.alert?.dismiss();
      this.busy = true;
      try {
        const { data, perPage, total } = await fetchTokens(this.urlShow, this.id, this.params);
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
    setup({ id, filters, urlShow }) {
      this.id = id;
      this.filters = filters;
      this.urlShow = urlShow;
    },
    setFilters(filters) {
      this.filters = filters;
    },
    setPage(page) {
      this.page = page;
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
  },
});

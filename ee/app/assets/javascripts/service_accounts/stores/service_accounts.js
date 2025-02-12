import { defineStore } from 'pinia';
import axios from '~/lib/utils/axios_utils';
import { parseIntPagination, normalizeHeaders } from '~/lib/utils/common_utils';

import { createAlert } from '~/alert';
import { s__ } from '~/locale';

export const useServiceAccounts = defineStore('serviceAccounts', {
  state() {
    return {
      alert: null,
      serviceAccounts: [],
      serviceAccountCount: 0,
      busy: false,
    };
  },
  actions: {
    async fetchServiceAccounts(url, { page, perPage }) {
      this.alert?.dismiss();
      this.busy = true;
      try {
        const { data, headers } = await axios.get(url, {
          params: {
            page,
            per_page: perPage,
            orderBy: 'name',
          },
        });

        const { total } = parseIntPagination(normalizeHeaders(headers));

        this.serviceAccountCount = total;
        this.serviceAccounts = data;
      } catch {
        this.alert = createAlert({
          message: s__('ServiceAccounts|An error occurred while fetching the service accounts.'),
        });
      } finally {
        this.busy = false;
      }
    },
    addServiceAccount() {
      // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/509870
    },
  },
  getters: {},
});

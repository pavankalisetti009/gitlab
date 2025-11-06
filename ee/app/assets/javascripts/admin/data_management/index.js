import Vue from 'vue';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { formatListboxItems } from 'ee/admin/data_management/filters';
import { FILTERED_SEARCH_TOKEN_OPTIONS } from 'ee/admin/data_management/constants';

export const initAdminDataManagementApp = () => {
  const el = document.getElementById('js-admin-data-management');

  if (!el) return null;

  const { initialModelName, modelTypes } = el.dataset;

  const parsedModelTypes = convertObjectPropsToCamelCase(JSON.parse(modelTypes), { deep: true });

  return new Vue({
    el,
    provide: {
      listboxItems: formatListboxItems(parsedModelTypes),
      filteredSearchTokens: FILTERED_SEARCH_TOKEN_OPTIONS,
    },
    render(createElement) {
      return createElement(AdminDataManagementApp, {
        props: {
          initialModelName,
          modelTypes: parsedModelTypes,
        },
      });
    },
  });
};

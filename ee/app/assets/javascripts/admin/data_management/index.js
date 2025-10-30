import Vue from 'vue';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { formatListboxItems } from 'ee/admin/data_management/filters';
import { FILTERED_SEARCH_TOKEN_OPTIONS } from 'ee/admin/data_management/constants';

export const initAdminDataManagementApp = () => {
  const el = document.getElementById('js-admin-data-management');

  if (!el) return null;

  const modelTypes = convertObjectPropsToCamelCase(JSON.parse(el.dataset.modelTypes), {
    deep: true,
  });

  const modelClass = convertObjectPropsToCamelCase(JSON.parse(el.dataset.modelClassData));

  return new Vue({
    el,
    provide: {
      listboxItems: formatListboxItems(modelTypes),
      filteredSearchTokens: FILTERED_SEARCH_TOKEN_OPTIONS,
    },
    render(createElement) {
      return createElement(AdminDataManagementApp, {
        props: {
          modelClass,
        },
      });
    },
  });
};

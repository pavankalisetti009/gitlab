import Vue from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { namespaceWorkItemTypesQueryResponse } from 'ee_else_ce_jest/work_items/mock_data';
import { getRoutes } from 'ee/groups/settings/work_items/routes';
import organisationWorkItemTypesQuery from '~/work_items/graphql/organisation_work_item_types.query.graphql';
import AdminWorkItemSettings from './admin_work_item_settings.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initAdminWorkItemSettings = () => {
  const el = document.querySelector('#js-admin-work-item-settings');

  if (!el) {
    return false;
  }

  const { basePath } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: organisationWorkItemTypesQuery,
    data: {
      organisation: {
        id: 'gid://gitlab/2',
        workItemTypes: {
          nodes: [...namespaceWorkItemTypesQueryResponse.data.namespace.workItemTypes.nodes],
        },
      },
    },
  });

  return new Vue({
    el,
    router: new VueRouter({
      mode: 'history',
      base: basePath,
      routes: getRoutes(''),
    }),
    apolloProvider,
    name: 'AdminWorkItemSettings',
    render(createElement) {
      return createElement(AdminWorkItemSettings);
    },
  });
};

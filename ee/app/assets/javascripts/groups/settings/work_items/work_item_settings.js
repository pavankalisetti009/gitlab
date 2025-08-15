import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import Translate from '~/vue_shared/translate';
import WorkItemSettings from './work_item_settings.vue';
import namespaceDefaultLifecycleQuery from './custom_status/namespace_default_lifecycle.query.graphql';

Vue.use(VueApollo);
Vue.use(Translate);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initWorkItemSettingsApp() {
  const el = document.querySelector('#js-work-items-settings-form');
  if (!el) return;

  const { fullPath } = el.dataset;

  /** TODO remove the below code once the API is in place */
  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: namespaceDefaultLifecycleQuery,
    variables: {
      fullPath,
    },
    data: {
      namespaceDefaultLifecycle: {
        __typename: 'LocalNamespace',
        id: 'gid://gitlab/Namespace/default',
        lifecycle: {
          id: 'gid://gitlab/Lifecycle/default',
          /* eslint-disable @gitlab/require-i18n-strings */
          name: 'Default',
          defaultOpenStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/87',
            /* eslint-disable @gitlab/require-i18n-strings */
            name: 'To do',
            __typename: 'LocalWorkItemStatus',
          },
          defaultClosedStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/89',
            /* eslint-disable @gitlab/require-i18n-strings */
            name: 'Done',
            __typename: 'LocalWorkItemStatus',
          },
          defaultDuplicateStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/91',
            /* eslint-disable @gitlab/require-i18n-strings */
            name: 'Duplicate',
            __typename: 'LocalWorkItemStatus',
          },
          workItemTypes: [],
          statuses: [
            {
              id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/87',
              /* eslint-disable @gitlab/require-i18n-strings */
              name: 'To do',
              iconName: 'status-waiting',
              color: '#737278',
              description: null,
              __typename: 'LocalWorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/88',
              /* eslint-disable @gitlab/require-i18n-strings */
              name: 'In progress',
              iconName: 'status-running',
              color: '#1f75cb',
              description: null,
              __typename: 'LocalWorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/89',
              /* eslint-disable @gitlab/require-i18n-strings */
              name: 'Done',
              iconName: 'status-success',
              color: '#108548',
              description: null,
              __typename: 'LocalWorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/90',
              /* eslint-disable @gitlab/require-i18n-strings */
              name: "Won't do",
              iconName: 'status-cancelled',
              color: '#DD2B0E',
              description: null,
              __typename: 'LocalWorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/91',
              /* eslint-disable @gitlab/require-i18n-strings */
              name: 'Duplicate',
              iconName: 'status-cancelled',
              color: '#DD2B0E',
              description: null,
              __typename: 'LocalWorkItemStatus',
            },
          ],
          __typename: 'LocalLifecycle',
        },
      },
    },
  });

  // eslint-disable-next-line no-new
  new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(WorkItemSettings, {
        props: {
          fullPath,
        },
      });
    },
  });
}

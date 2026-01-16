import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import SpaRoot from '~/vue_shared/spa/components/spa_root.vue';
import getUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams_count.query.graphql';
import ContainerVirtualRegistryBreadcrumbs from './breadcrumbs.vue';
import createRouter from './router';
import i18n from './i18n';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-vue-container-virtual-registries');
  const { basePath, fullPath } = el.dataset;

  const router = createRouter(basePath);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(
      {},
      {
        cacheConfig: {
          typePolicies: {
            ContainerUpstreamConnection: { merge: true },
          },
        },
      },
    ),
  });

  injectVueAppBreadcrumbs(router, ContainerVirtualRegistryBreadcrumbs, apolloProvider);

  return new Vue({
    el,
    name: 'ContainerVirtualRegistry',
    router,
    apolloProvider,
    provide: {
      basePath,
      fullPath,
      i18n,
      getUpstreamsQuery,
      getUpstreamsCountQuery,
    },
    render(createElement) {
      return createElement(SpaRoot);
    },
  });
};

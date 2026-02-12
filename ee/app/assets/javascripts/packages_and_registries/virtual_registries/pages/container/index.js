import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import SpaRoot from '~/vue_shared/spa/components/spa_root.vue';
import getRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_virtual_registries.query.graphql';
import getRegistryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_registry.query.graphql';
import getUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams_count.query.graphql';
import getUpstreamRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream_registries.query.graphql';
import createRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_container_registry.mutation.graphql';
import updateRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/update_container_registry.mutation.graphql';
import getUpstreamSummaryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream_summary.query.graphql';
import getUpstreamCacheEntriesCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream_cache_entries_count.query.graphql';
import getUpstreamCacheEntriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream_cache_entries.query.graphql';
import deleteRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_registry.mutation.graphql';
import deleteUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_upstream.mutation.graphql';
import deleteUpstreamCacheMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_upstream_cache.mutation.graphql';
import ContainerVirtualRegistryBreadcrumbs from './breadcrumbs.vue';
import i18n from './i18n';
import createRouter from './router';
import routes from './routes';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-vue-container-virtual-registries');
  const { basePath, fullPath, maxRegistriesCount } = el.dataset;

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
      fullPath,
      ids: {
        baseUpstream: 'VirtualRegistries::Container::Upstream',
        baseRegistry: 'VirtualRegistries::Container::Registry',
      },
      i18n,
      routes,
      getRegistriesQuery,
      getRegistryQuery,
      getUpstreamsQuery,
      getUpstreamsCountQuery,
      getUpstreamRegistriesQuery,
      createRegistryMutation,
      updateRegistryMutation,
      getUpstreamSummaryQuery,
      getUpstreamCacheEntriesQuery,
      getUpstreamCacheEntriesCountQuery,
      deleteRegistryMutation,
      deleteUpstreamMutation,
      deleteUpstreamCacheMutation,
      maxRegistriesCount: Number(maxRegistriesCount),
    },
    render(createElement) {
      return createElement(SpaRoot);
    },
  });
};

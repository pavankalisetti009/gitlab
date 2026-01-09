import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import SpaRoot from '~/vue_shared/spa/components/spa_root.vue';
import ContainerVirtualRegistryBreadcrumbs from './breadcrumbs.vue';
import createRouter from './router';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-vue-container-virtual-registries');
  const { basePath, fullPath } = el.dataset;

  const router = createRouter(basePath);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
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
    },
    render(createElement) {
      return createElement(SpaRoot);
    },
  });
};

import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import SpaRoot from '~/vue_shared/spa/components/spa_root.vue';
import RegistriesAndUpstreams from 'ee/packages_and_registries/virtual_registries/pages/container/registries_and_upstreams.vue';
import { CONTAINER_REGISTRIES_INDEX, CONTAINER_UPSTREAMS_INDEX } from './routes';
import { updateDocumentTitle } from './utils';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      { path: '/', redirect: { name: CONTAINER_REGISTRIES_INDEX } },
      {
        path: '/',
        component: SpaRoot,
        children: [
          {
            path: 'registries',
            component: SpaRoot,
            meta: {
              text: s__('VirtualRegistries|Container registries'),
            },
            children: [
              {
                name: CONTAINER_REGISTRIES_INDEX,
                path: '',
                component: RegistriesAndUpstreams,
              },
            ],
          },
          {
            path: 'upstreams',
            component: SpaRoot,
            meta: {
              text: s__('VirtualRegistries|Container upstreams'),
            },
            children: [
              {
                name: CONTAINER_UPSTREAMS_INDEX,
                path: '',
                component: RegistriesAndUpstreams,
              },
            ],
          },
        ],
      },
      { path: '*', redirect: { name: CONTAINER_REGISTRIES_INDEX } },
    ],
  });

  router.afterEach(updateDocumentTitle());

  return router;
}

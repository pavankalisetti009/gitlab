import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import SpaRoot from '~/vue_shared/spa/components/spa_root.vue';
import RegistriesNewPage from '../common/registry/new.vue';
import RegistriesAndUpstreams from './registries_and_upstreams.vue';
import RegistriesEdit from './registries_edit.vue';
import RegistriesShow from './registries_show.vue';
import {
  CONTAINER_REGISTRIES_INDEX,
  CONTAINER_REGISTRIES_EDIT,
  CONTAINER_REGISTRIES_SHOW,
  CONTAINER_UPSTREAMS_INDEX,
} from './routes';
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
              defaultRoute: CONTAINER_REGISTRIES_INDEX,
            },
            children: [
              {
                name: CONTAINER_REGISTRIES_INDEX,
                path: '',
                component: RegistriesAndUpstreams,
              },
              {
                name: 'REGISTRY_NEW',
                path: 'new',
                component: RegistriesNewPage,
                beforeEnter(to, from, next) {
                  if (window.gon?.abilities?.createVirtualRegistry) {
                    next();
                  } else {
                    next({
                      name: CONTAINER_REGISTRIES_INDEX,
                    });
                  }
                },
              },
              {
                path: ':id(\\d+)',
                component: SpaRoot,
                meta: {
                  useId: true,
                  defaultRoute: CONTAINER_REGISTRIES_SHOW,
                },
                children: [
                  {
                    name: CONTAINER_REGISTRIES_SHOW,
                    path: '',
                    component: RegistriesShow,
                    props: true,
                  },
                  {
                    name: CONTAINER_REGISTRIES_EDIT,
                    path: 'edit',
                    component: RegistriesEdit,
                    props: true,
                    meta: {
                      text: s__('VirtualRegistries|Edit registry'),
                    },
                  },
                ],
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

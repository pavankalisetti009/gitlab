import Vue from 'vue';
import VueRouter from 'vue-router';
import { joinPaths } from '~/lib/utils/url_utility';
import NewSelfHostedModel from './self_hosted_models/components/new_self_hosted_model.vue';
import EditSelfHostedModel from './self_hosted_models/components/edit_self_hosted_model.vue';
import DuoSelfHostedApp from './app.vue';
import { SELF_HOSTED_DUO_TABS } from './constants';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', base),
    routes: [
      {
        name: 'index',
        path: '/',
        component: DuoSelfHostedApp,
      },
      {
        name: 'new',
        path: '/new',
        component: NewSelfHostedModel,
      },
      {
        name: 'edit',
        path: '/:id/edit',
        component: EditSelfHostedModel,
        props: ({ params: { id } }) => {
          return { modelId: Number(id) };
        },
      },
      {
        name: 'features',
        path: '/features',
        component: DuoSelfHostedApp,
        props: () => ({ tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS }),
      },
      {
        name: 'models',
        path: '/models',
        component: DuoSelfHostedApp,
        props: () => ({ tabId: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS }),
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  return router;
}

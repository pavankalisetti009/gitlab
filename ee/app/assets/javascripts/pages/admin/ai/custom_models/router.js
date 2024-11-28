import Vue from 'vue';
import VueRouter from 'vue-router';
import { joinPaths } from '~/lib/utils/url_utility';
import NewSelfHostedModel from '../self_hosted_models/components/new_self_hosted_model.vue';
import EditSelfHostedModel from '../self_hosted_models/components/edit_self_hosted_model.vue';
import SelfHostedDuoConfiguration from './self_hosted_duo_configuration.vue';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', base),
    routes: [
      {
        name: 'index',
        path: '/',
        component: SelfHostedDuoConfiguration,
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
        component: SelfHostedDuoConfiguration,
        props: () => ({ tabId: 'ai-feature-settings' }),
      },

      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  return router;
}

import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from './context_config';
import createRouter from './router';
import SecretsApp from './components/secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';
import { ENTITY_GROUP, ENTITY_PROJECT } from './constants';

Vue.use(VueApollo);
Vue.use(GlToast);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

// eslint-disable-next-line max-params
const initSecretsApp = (el, app, provide, basePath) => {
  const router = createRouter(basePath, provide);

  if (window.location.href.includes(basePath)) {
    injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);
  }

  return new Vue({
    el,
    router,
    name: 'SecretsRoot',
    provide,
    apolloProvider,
    render(createElement) {
      return createElement(app, { provide });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, basePath } = el.dataset;

  return initSecretsApp(
    el,
    SecretsApp,
    { contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_GROUP], fullPath: groupPath },
    basePath,
  );
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, basePath } = el.dataset;

  return initSecretsApp(
    el,
    SecretsApp,
    { contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_PROJECT], fullPath: projectPath },
    basePath,
  );
};

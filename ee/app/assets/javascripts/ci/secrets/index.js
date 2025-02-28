import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import createRouter, { initNavigationGuards } from './router';
import SecretsApp from './components/secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

// eslint-disable-next-line max-params
const initSecretsApp = (el, app, props, basePath) => {
  const router = createRouter(basePath, props, window.location.href);

  if (window.location.href.includes(basePath)) {
    injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);
  }

  initNavigationGuards({ router, base: basePath, props, location: window.location.href });

  return new Vue({
    el,
    router,
    name: 'SecretsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(app, { props });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, groupId, basePath } = el.dataset;

  return initSecretsApp(el, SecretsApp, { groupPath, groupId }, basePath);
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, projectSecretsSettingsPath, projectId, basePath } = el.dataset;

  return initSecretsApp(
    el,
    SecretsApp,
    { projectPath, projectSecretsSettingsPath, projectId },
    basePath,
  );
};

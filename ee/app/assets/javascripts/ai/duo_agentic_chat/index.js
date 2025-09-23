import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { activeWorkItemIds } from '~/work_items/utils';
import store from '../tanuki_bot/store';
import routes from './routes';
import DuoAgenticLayoutApp from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const createRouter = () => {
  const router = new VueRouter({
    routes,
    mode: 'abstract',
  });

  return router;
};

export const initDuoAgenticChat = () => {
  const el = document.getElementById('js-duo-agentic-chat-app');

  if (!el) {
    return false;
  }

  Vue.use(VueRouter);

  const {
    projectId,
    namespaceId,
    rootNamespaceId,
    resourceId,
    metadata,
    userModelSelectionEnabled,
  } = el.dataset;

  return new Vue({
    el,
    store: store(),
    router: createRouter(),
    provide: {
      isSidePanelView: true,
      isFlyout: true,
    },
    apolloProvider,
    render(createElement) {
      const latestActiveWorkItemId = activeWorkItemIds.value[activeWorkItemIds.value.length - 1];
      return createElement(DuoAgenticLayoutApp, {
        props: {
          projectId,
          namespaceId,
          rootNamespaceId,
          resourceId: latestActiveWorkItemId ?? resourceId,
          metadata,
          userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
        },
      });
    },
  });
};

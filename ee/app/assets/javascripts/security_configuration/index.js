import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import SecurityConfigurationApp from './components/app.vue';
import resolvers from './security_attributes/graphql/resolvers';

Vue.use(VueApollo);

export const initSecurityConfiguration = (el) => {
  if (!el) {
    return null;
  }

  const { groupFullPath, namespaceId } = el.dataset;

  return new Vue({
    el,
    name: 'SecurityConfigurationRoot',
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(resolvers),
    }),
    provide: {
      groupFullPath,
      namespaceId,
    },
    render(createElement) {
      return createElement(SecurityConfigurationApp);
    },
  });
};

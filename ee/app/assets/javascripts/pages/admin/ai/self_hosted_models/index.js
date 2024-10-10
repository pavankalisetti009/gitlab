import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import SelfHostedDuoConfiguration from '../custom_models/self_hosted_duo_configuration.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

function mountSelfHostedModelsApp() {
  const el = document.getElementById('js-self-hosted-models');

  if (!el) {
    return null;
  }

  const { basePath, newSelfHostedModelPath, aiFeatureSettingsPath } = el.dataset;

  return new Vue({
    el,
    name: 'SelfHostedDuoConfigurationApp',
    apolloProvider,
    provide: {
      basePath,
      newSelfHostedModelPath,
      aiFeatureSettingsPath,
    },
    render: (h) => h(SelfHostedDuoConfiguration),
  });
}

mountSelfHostedModelsApp();

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import PremiumMessageDuringTrial from './components/premium_message_during_trial.vue';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-premium-message-during-trial');

  if (!el) {
    return null;
  }

  const { featureId, groupId, page, upgradeUrl } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    render(h) {
      return h(PremiumMessageDuringTrial, {
        props: {
          featureId,
          groupId,
          page,
          upgradeUrl,
        },
      });
    },
  });
};

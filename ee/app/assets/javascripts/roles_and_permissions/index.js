import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import CustomRolesApp from './components/app.vue';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCustomRolesApp = () => {
  const el = document.querySelector('#js-roles-and-permissions');

  if (!el) {
    return null;
  }

  const { groupFullPath, newRolePath } = el.dataset;

  return new Vue({
    el,
    name: 'CustomRolesRoot',
    apolloProvider,
    mixins: [InternalEvents.mixin()],
    mounted() {
      this.trackEvent('view_admin_application_settings_roles_and_permissions_pageload');
    },
    render(createElement) {
      return createElement(CustomRolesApp, {
        props: { groupFullPath, newRolePath },
      });
    },
  });
};

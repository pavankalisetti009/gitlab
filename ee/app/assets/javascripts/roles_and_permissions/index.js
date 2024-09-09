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

  const { documentationPath, emptyStateSvgPath, groupFullPath, newRolePath } = el.dataset;

  return new Vue({
    el,
    name: 'CustomRolesRoot',
    apolloProvider,
    mixins: [InternalEvents.mixin()],
    provide: {
      documentationPath,
      emptyStateSvgPath,
      groupFullPath,
      newRolePath,
    },
    mounted() {
      this.trackEvent('view_admin_application_settings_roles_and_permissions_pageload');
    },
    render(createElement) {
      return createElement(CustomRolesApp);
    },
  });
};

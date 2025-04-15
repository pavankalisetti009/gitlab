import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import { initPlannerRoleBanner } from '~/planner_role_banner';
import { parseBoolean } from '~/lib/utils/common_utils';
import RoleTabs from './components/role_tabs.vue';

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

  initPlannerRoleBanner();

  const { groupFullPath, groupId, newRolePath, currentUserEmail, ldapEnabled } = el.dataset;

  return new Vue({
    el,
    name: 'RolesRoot',
    apolloProvider,
    mixins: [InternalEvents.mixin()],
    provide: { groupId, currentUserEmail, groupFullPath, newRolePath },
    mounted() {
      this.trackEvent('view_admin_application_settings_roles_and_permissions_pageload');
    },
    render(createElement) {
      return createElement(RoleTabs, {
        props: { isLdapEnabled: parseBoolean(ldapEnabled) },
      });
    },
  });
};

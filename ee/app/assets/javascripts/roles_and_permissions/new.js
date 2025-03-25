import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import RoleCreate from './components/manage_role/role_create.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCreateMemberRoleApp = () => {
  const el = document.querySelector('#js-create-member-role');

  if (!el) {
    return null;
  }

  const { groupFullPath, listPagePath } = el.dataset;

  return new Vue({
    el,
    name: 'CreateRoleRoot',
    apolloProvider,
    render(createElement) {
      return createElement(RoleCreate, {
        props: { groupFullPath, listPagePath },
      });
    },
  });
};

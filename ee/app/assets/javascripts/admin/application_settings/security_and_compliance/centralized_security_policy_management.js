import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import CentralizedSecurityPolicyManagement from './components/centralized_security_policy_management.vue';

export const initCentralizedSecurityPolicyManagement = () => {
  const el = document.getElementById('js-centralized_security_policy_management');

  if (!el) return false;

  const {
    centralizedSecurityPolicyGroupId,
    centralizedSecurityPolicyGroupLocked,
    formId,
    newGroupPath,
  } = el.dataset;

  return new Vue({
    apolloProvider,
    el,
    name: 'CentralizedSecurityPolicyManagementRoot',
    render(createElement) {
      return createElement(CentralizedSecurityPolicyManagement, {
        props: {
          centralizedSecurityPolicyGroupLocked: parseBoolean(centralizedSecurityPolicyGroupLocked),
          formId,
          initialSelectedGroupId: parseInt(centralizedSecurityPolicyGroupId, 10),
          newGroupPath,
        },
      });
    },
  });
};

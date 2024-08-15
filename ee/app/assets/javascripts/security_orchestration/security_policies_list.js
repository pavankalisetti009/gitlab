import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import SecurityPoliciesListApp from './components/policies/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from './constants';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    assignedPolicyProject,
    disableSecurityPolicyProject,
    disableScanPolicyUpdate,
    emptyFilterSvgPath,
    emptyListSvgPath,
    documentationPath,
    newPolicyPath,
    namespacePath,
    rootNamespacePath,
  } = el.dataset;

  let parsedAssignedPolicyProject;

  try {
    parsedAssignedPolicyProject = convertObjectPropsToCamelCase(JSON.parse(assignedPolicyProject));
  } catch {
    parsedAssignedPolicyProject = DEFAULT_ASSIGNED_POLICY_PROJECT;
  }

  return new Vue({
    apolloProvider,
    el,
    name: 'PoliciesAppRoot',
    provide: {
      assignedPolicyProject: parsedAssignedPolicyProject,
      disableSecurityPolicyProject: parseBoolean(disableSecurityPolicyProject),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      documentationPath,
      newPolicyPath,
      emptyFilterSvgPath,
      emptyListSvgPath,
      namespacePath,
      namespaceType,
      rootNamespacePath,
    },
    render(createElement) {
      return createElement(SecurityPoliciesListApp);
    },
  });
};

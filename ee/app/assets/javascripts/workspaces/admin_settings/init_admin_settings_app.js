import Vue from 'vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_ORGANIZATION } from '~/graphql_shared/constants';
import { parseBoolean } from '~/lib/utils/common_utils';

import WorkspacesAgentAvailabilityApp from './pages/app.vue';

const initWorkspacesAgentAvailabilityApp = () => {
  const el = document.getElementById('js-workspaces-agent-availability-settings');

  if (!el?.dataset) return null;

  const { organizationId, defaultExpanded } = el.dataset;

  return new Vue({
    el,
    components: {
      WorkspacesAgentAvailabilityApp,
    },
    provide: {
      organizationId: convertToGraphQLId(TYPE_ORGANIZATION, organizationId),
      defaultExpanded: parseBoolean(defaultExpanded),
    },
    render(createElement) {
      return createElement(WorkspacesAgentAvailabilityApp);
    },
  });
};

export { initWorkspacesAgentAvailabilityApp };

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { TYPE_ISSUE } from '~/issues/constants';
import { parseBoolean } from '~/lib/utils/common_utils';
import * as CEMountSidebar from '~/sidebar/mount_sidebar';
import { pinia } from '~/pinia/instance';
import CveIdRequest from './components/cve_id_request/cve_id_request.vue';
import SidebarIterationWidget from './components/iteration/sidebar_iteration_widget.vue';
import SidebarHealthStatusWidget from './components/health_status/sidebar_health_status_widget.vue';
import SidebarWeightWidget from './components/weight/sidebar_weight_widget.vue';
import SidebarEscalationPolicy from './components/incidents/sidebar_escalation_policy.vue';
import { IssuableAttributeType } from './constants';

Vue.use(VueApollo);

const mountSidebarWeightWidget = () => {
  const el = document.querySelector('.js-sidebar-weight-widget-root');

  if (!el) {
    return null;
  }

  const { canEdit, projectPath, issueIid } = el.dataset;

  return new Vue({
    el,
    name: 'SidebarWeightWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    render: (createElement) =>
      createElement(SidebarWeightWidget, {
        props: {
          fullPath: projectPath,
          iid: issueIid,
          issuableType: TYPE_ISSUE,
        },
      }),
  });
};

const mountSidebarHealthStatusWidget = () => {
  const el = document.querySelector('.js-sidebar-health-status-widget-root');

  if (!el) {
    return null;
  }

  const { iid, fullPath, issuableType, canEdit } = el.dataset;

  return new Vue({
    el,
    name: 'SidebarHealthStatusWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
    },
    render: (createElement) =>
      createElement(SidebarHealthStatusWidget, {
        props: {
          fullPath,
          iid,
          issuableType,
        },
      }),
  });
};

function mountSidebarCveIdRequest() {
  const el = document.querySelector('.js-sidebar-cve-id-request-root');

  if (!el) {
    return null;
  }

  const { iid, fullPath } = CEMountSidebar.getSidebarOptions();

  return new Vue({
    pinia,
    el,
    name: 'SidebarCveIdRequestRoot',
    provide: {
      iid: String(iid),
      fullPath,
    },
    render: (createElement) => createElement(CveIdRequest),
  });
}

function mountSidebarIterationWidget() {
  const el = document.querySelector('.js-sidebar-iteration-widget-root');

  if (!el) {
    return null;
  }

  const { groupPath, canEdit, projectPath, issueIid, issueId } = el.dataset;

  return new Vue({
    el,
    name: 'SidebarIterationWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    render: (createElement) =>
      createElement(SidebarIterationWidget, {
        props: {
          attrWorkspacePath: groupPath,
          workspacePath: projectPath,
          iid: issueIid,
          issuableType: TYPE_ISSUE,
          issueId,
          issuableAttribute: IssuableAttributeType.Iteration,
        },
      }),
  });
}

function mountSidebarEscalationPolicy() {
  const el = document.querySelector('.js-sidebar-escalation-policy-root');

  if (!el) {
    return null;
  }

  const { canEdit, projectPath, issueIid, hasEscalationPolicies, issueId } = el.dataset;

  return new Vue({
    el,
    name: 'SidebarEscalationPolicyRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    render: (createElement) =>
      createElement(SidebarEscalationPolicy, {
        props: {
          projectPath,
          iid: issueIid,
          escalationsPossible: parseBoolean(hasEscalationPolicies),
          issueId,
        },
      }),
  });
}

export const { getSidebarOptions } = CEMountSidebar;

export function mountSidebar(mediator) {
  CEMountSidebar.mountSidebar(mediator);
  mountSidebarWeightWidget();
  mountSidebarHealthStatusWidget();
  mountSidebarIterationWidget();
  mountSidebarEscalationPolicy();
  mountSidebarCveIdRequest();
}

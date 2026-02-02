import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import GroupActivityCard from './components/group_activity_card.vue';

export default () => {
  const container = document.getElementById('js-group-activity');

  if (!container) return;

  const {
    currentUserIsOwner,
    showPlanIndicator,
    groupBillingsPath,
    groupSubscriptionPlanName,
    groupFullPath,
    groupName,
    mergeRequestsMetricLink,
    issuesMetricLink,
    newMembersMetricLink,
  } = container.dataset;

  // eslint-disable-next-line no-new
  new Vue({
    el: container,
    name: 'GroupActivityCardRoot',
    provide: {
      currentUserIsOwner: parseBoolean(currentUserIsOwner),
      showPlanIndicator: parseBoolean(showPlanIndicator),
      groupBillingsPath,
      groupSubscriptionPlanName,
      groupFullPath,
      groupName,
      mergeRequestsMetricLink,
      issuesMetricLink,
      newMembersMetricLink,
    },
    render(h) {
      return h(GroupActivityCard);
    },
  });
};

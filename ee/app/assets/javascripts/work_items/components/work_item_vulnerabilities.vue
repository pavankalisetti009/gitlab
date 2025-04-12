<script>
import { findWidget } from '~/issues/list/utils';
import { WIDGET_TYPE_VULNERABILITIES } from '~/work_items/constants';
import workItemVulnerabilitiesQuery from '../graphql/work_item_vulnerabilities.query.graphql';

export default {
  props: {
    workItemId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      workItemVulnerabilities: {},
    };
  },
  computed: {
    relatedVulnerabilities() {
      return this.workItemVulnerabilities.relatedVulnerabilities?.nodes || [];
    },
  },
  apollo: {
    workItemVulnerabilities: {
      query: workItemVulnerabilitiesQuery,
      variables() {
        return {
          id: this.workItemId,
        };
      },
      update(data) {
        return findWidget(WIDGET_TYPE_VULNERABILITIES, data?.workItem) || {};
      },
      skip() {
        return !this.workItemId;
      },
    },
  },
};
</script>

<template>
  <div>{{ relatedVulnerabilities.length }}</div>
</template>

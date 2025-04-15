<script>
import { GlBadge } from '@gitlab/ui';
import { n__, sprintf } from '~/locale';
import { VULNERABILITIES_ITEMS_ANCHOR, WIDGET_TYPE_VULNERABILITIES } from '~/work_items/constants';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { findWidget } from '~/issues/list/utils';
import workItemVulnerabilitiesQuery from '../graphql/work_item_vulnerabilities.query.graphql';
import WorkItemVulnerabilityItem from './work_item_vulnerability_item.vue';

export default {
  components: {
    CrudComponent,
    GlBadge,
    WorkItemVulnerabilityItem,
  },
  props: {
    workItemFullPath: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
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
    relatedVulnerabilitiesCount() {
      return this.relatedVulnerabilities.length;
    },
    hasRelatedVulnerabilities() {
      return this.relatedVulnerabilitiesCount > 0;
    },
    countBadgeAriaLabel() {
      return sprintf(
        n__(
          'WorkItem|Issue has 1 related vulnerability',
          'WorkItem|Issue has %{itemCount} related vulnerabilities',
          this.relatedVulnerabilitiesCount,
        ),
        { itemCount: this.relatedVulnerabilitiesCount },
      );
    },
  },
  apollo: {
    workItemVulnerabilities: {
      query: workItemVulnerabilitiesQuery,
      variables() {
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
        };
      },
      update(data) {
        return findWidget(WIDGET_TYPE_VULNERABILITIES, data.workspace?.workItem) || {};
      },
      skip() {
        return !this.workItemIid;
      },
    },
  },
  VULNERABILITIES_ITEMS_ANCHOR,
};
</script>

<template>
  <crud-component
    v-if="hasRelatedVulnerabilities"
    :title="s__('WorkItem|Related vulnerabilities')"
    :anchor-id="$options.VULNERABILITIES_ITEMS_ANCHOR"
    is-collapsible
    persist-collapsed-state
  >
    <template #count>
      <gl-badge :aria-label="countBadgeAriaLabel" variant="muted">
        {{ relatedVulnerabilitiesCount }}
      </gl-badge>
    </template>

    <ul class="content-list">
      <li v-for="item in relatedVulnerabilities" :key="item.id">
        <work-item-vulnerability-item :item="item" />
      </li>
    </ul>
  </crud-component>
</template>

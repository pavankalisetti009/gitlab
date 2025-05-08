<script>
import { GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import SubgroupsQuery from '../../graphql/subgroups.query.graphql';
import ExpandableGroup from './expandable_group.vue';

export default {
  components: {
    ExpandableGroup,
    GlIntersectionObserver,
    GlLoadingIcon,
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
    },
    activeFullPath: {
      type: String,
      required: false,
      default: '',
    },
    indentation: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      group: {
        descendantGroups: {
          edges: [],
        },
      },
    };
  },
  apollo: {
    group: {
      query: SubgroupsQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      error(error) {
        createAlert({
          message: s__(
            'SecurityInventory|An error occurred while fetching subgroups. Please try again.',
          ),
          error,
          captureError: true,
        });
        Sentry.captureException(error);
      },
    },
  },
  methods: {
    selectSubgroup(subgroupFullPath) {
      this.$emit('selectSubgroup', subgroupFullPath);
    },
    fetchMoreSubgroups() {
      const { hasNextPage, endCursor } = this.group.descendantGroups.pageInfo || {};
      if (!hasNextPage) return;
      this.$apollo.queries.group.fetchMore({ variables: { after: endCursor } });
    },
  },
};
</script>
<template>
  <div>
    <expandable-group
      v-for="subgroup in group.descendantGroups.edges.map((edge) => edge.node)"
      :key="subgroup.id"
      :group="subgroup"
      :active-full-path="activeFullPath"
      :indentation="indentation"
      @selectSubgroup="selectSubgroup"
    />
    <gl-loading-icon v-if="$apollo.queries.group.loading" class="gl-pt-3" />
    <gl-intersection-observer v-else @appear="fetchMoreSubgroups" />
  </div>
</template>

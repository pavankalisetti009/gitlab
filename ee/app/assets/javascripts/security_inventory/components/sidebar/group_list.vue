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
          nodes: [],
          pageInfo: {
            hasNextPage: true,
          },
        },
      },
      loading: false,
      scrolledToEndWithNextPage: false,
    };
  },
  apollo: {
    group: {
      query: SubgroupsQuery,
      client: 'appendGroupsClient',
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
  computed: {
    hasNextPage() {
      return this.group.descendantGroups.pageInfo?.hasNextPage;
    },
  },
  methods: {
    selectSubgroup(subgroupFullPath) {
      this.$emit('selectSubgroup', subgroupFullPath);
    },
    async fetchMoreSubgroups() {
      if (!this.hasNextPage) return;
      this.loading = true;
      await this.$apollo.queries.group.fetchMore({
        variables: {
          after: this.group.descendantGroups.pageInfo?.endCursor,
        },
      });
      this.loading = false;

      if (this.scrolledToEndWithNextPage) {
        this.fetchMoreSubgroups();
      }
    },
    checkScrolledToEnd(observer) {
      this.scrolledToEndWithNextPage = this.hasNextPage && observer.isIntersecting;
    },
  },
};
</script>
<template>
  <div>
    <expandable-group
      v-for="subgroup in group.descendantGroups.nodes"
      :key="subgroup.id"
      :group="subgroup"
      :active-full-path="activeFullPath"
      :indentation="indentation"
      @selectSubgroup="selectSubgroup"
    />
    <gl-intersection-observer @appear="fetchMoreSubgroups" @update="checkScrolledToEnd" />
    <gl-loading-icon v-if="loading" />
  </div>
</template>

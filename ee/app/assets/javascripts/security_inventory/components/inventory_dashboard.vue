<script>
import { GlSkeletonLoader, GlBreadcrumb } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getLocationHash, PATH_SEPARATOR } from '~/lib/utils/url_utility';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import EmptyState from './empty_state.vue';
import SecurityInventoryTable from './security_inventory_table.vue';

export default {
  components: {
    GlSkeletonLoader,
    GlBreadcrumb,
    EmptyState,
    SecurityInventoryTable,
  },
  inject: ['groupFullPath', 'newProjectPath'],
  i18n: {
    errorFetchingChildren: s__(
      'SecurityInventory||An error occurred while fetching subgroups and projects. Please try again.',
    ),
  },
  data() {
    return {
      children: [],
      activeFullPath: this.groupFullPath,
    };
  },
  apollo: {
    children: {
      query: SubgroupsAndProjectsQuery,
      variables() {
        return {
          fullPath: this.activeFullPath,
        };
      },
      update(data) {
        return this.transformData(data);
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorFetchingChildren,
          error,
          captureError: true,
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.children.loading;
    },
    hasChildren() {
      return this.children.length > 0;
    },
    crumbs() {
      const pathParts = this.activeFullPath.split(PATH_SEPARATOR);
      let cumulativePath = '';

      return pathParts.map((path) => {
        cumulativePath = cumulativePath ? `${cumulativePath}${PATH_SEPARATOR}${path}` : path;
        return {
          text: path,
          to: {
            hash: `#${cumulativePath}`,
          },
        };
      });
    },
  },
  created() {
    this.handleLocationHashChange();
    window.addEventListener('hashchange', this.handleLocationHashChange);
  },
  beforeDestroy() {
    window.removeEventListener('hashchange', this.handleLocationHashChange);
  },
  methods: {
    transformData(data) {
      const groupData = data?.group;
      if (!groupData) return [];

      const descendantGroups = groupData?.descendantGroups?.nodes || [];
      const projects = groupData?.projects?.nodes || [];

      return [...descendantGroups, ...projects];
    },
    handleLocationHashChange() {
      let hash = getLocationHash();
      if (!hash) {
        hash = this.groupFullPath;
      }
      this.activeFullPath = hash;
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <gl-breadcrumb :items="crumbs" :auto-resize="true" size="md" class="gl-mb-5" />
    <template v-if="isLoading">
      <gl-skeleton-loader />
    </template>
    <template v-else-if="!hasChildren"><empty-state /></template>
    <security-inventory-table v-else :items="children" />
  </div>
</template>

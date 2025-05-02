<script>
import { GlBreadcrumb, GlButton } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getLocationHash, PATH_SEPARATOR } from '~/lib/utils/url_utility';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { SIDEBAR_VISIBLE_STORAGE_KEY } from '../constants';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import SubgroupSidebar from './sidebar/subgroup_sidebar.vue';
import EmptyState from './empty_state.vue';
import SecurityInventoryTable from './security_inventory_table.vue';

export default {
  components: {
    SubgroupSidebar,
    LocalStorageSync,
    GlBreadcrumb,
    GlButton,
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
      sidebarVisible: true,
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
    showEmptyState() {
      return !this.isLoading && !this.hasChildren;
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
    toggleSidebar(value = !this.sidebarVisible) {
      this.sidebarVisible = value;
    },
  },
  SIDEBAR_VISIBLE_STORAGE_KEY,
};
</script>

<template>
  <div class="gl-mt-5">
    <div
      class="gl-w-full gl-border-b-1 gl-border-t-1 gl-border-gray-100 gl-bg-neutral-10 gl-border-b-solid gl-border-t-solid"
    >
      <gl-button icon="sidebar" icon-only class="gl-m-3" @click="toggleSidebar()" />
    </div>
    <local-storage-sync
      v-model="sidebarVisible"
      :storage-key="$options.SIDEBAR_VISIBLE_STORAGE_KEY"
      @input="toggleSidebar"
    />
    <div class="gl-flex">
      <subgroup-sidebar v-if="sidebarVisible" :active-full-path="activeFullPath" />
      <div class="gl-w-auto gl-grow" :class="{ 'gl-pl-5': sidebarVisible }">
        <gl-breadcrumb :items="crumbs" :auto-resize="true" size="md" class="gl-my-5" />
        <empty-state v-if="showEmptyState" />
        <security-inventory-table v-else :items="children" :is-loading="isLoading" />
      </div>
    </div>
  </div>
</template>

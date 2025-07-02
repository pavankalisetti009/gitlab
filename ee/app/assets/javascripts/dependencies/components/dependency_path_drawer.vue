<script>
import {
  GlDrawer,
  GlTruncateText,
  GlBadge,
  GlAlert,
  GlCollapsibleListbox,
  GlSkeletonLoader,
  GlKeysetPagination,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { TYPENAME_SBOM_OCCURRENCE } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import getDependencyPaths from '../graphql/dependency_paths.query.graphql';
import { NAMESPACE_PROJECT } from '../constants';

export default {
  name: 'DependencyPathDrawer',
  components: {
    GlDrawer,
    GlTruncateText,
    GlBadge,
    GlAlert,
    GlCollapsibleListbox,
    GlSkeletonLoader,
    GlKeysetPagination,
  },
  inject: {
    namespaceType: {
      default: NAMESPACE_PROJECT,
    },
    projectFullPath: {
      default: '',
    },
    groupFullPath: {
      default: '',
    },
  },
  props: {
    occurrenceId: {
      type: Number,
      required: false,
      default: null,
    },
    dependencyPaths: {
      type: Array,
      required: false,
      default: () => [],
    },
    component: {
      type: Object,
      required: true,
    },
    limitExceeded: {
      type: Boolean,
      required: false,
      default: false,
    },
    showDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
    locations: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      localDependencyPaths: this.dependencyPaths,
      selectedProject: null,
      pageInfo: {},
      cursor: {
        after: null,
        before: null,
      },
    };
  },
  apollo: {
    localDependencyPaths: {
      query: getDependencyPaths,
      variables() {
        return {
          occurrence: convertToGraphQLId(TYPENAME_SBOM_OCCURRENCE, this.occurrence),
          fullPath: this.fullPath,
          ...this.cursor,
        };
      },
      skip() {
        return !this.fullPath || !this.occurrenceId;
      },
      update({ project }) {
        const { pageInfo = {}, nodes = [] } = project?.dependencyPaths || {};
        this.pageInfo = pageInfo;
        return nodes;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries.localDependencyPaths.loading;
    },
    isProject() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
    selectedProjectOccurrence() {
      return this.projectItems.find((project) => project.value === this.selectedProject)
        ?.occurrenceId;
    },
    occurrence() {
      return this.isProject ? this.occurrenceId : this.selectedProjectOccurrence;
    },
    fullPath() {
      if (this.namespaceType === NAMESPACE_PROJECT) return this.projectFullPath;
      return this.selectedProject;
    },
    showProjectDropdown() {
      return this.locations?.length > 0;
    },
    projectItems() {
      return this.locations
        .filter((item) => item.location.has_dependency_paths)
        .map(({ project, occurrence_id: occurrenceId }) => ({
          value: project.full_path,
          text: project.name,
          occurrenceId,
        }));
    },
    showPagination() {
      return this.pageInfo?.hasPreviousPage || this.pageInfo?.hasNextPage;
    },
  },
  watch: {
    occurrenceId() {
      this.resetPagination();
    },
    locations: {
      handler() {
        this.selectedProject = this.projectItems[0]?.value ?? null;
      },
      immediate: true,
    },
  },
  methods: {
    resetPagination() {
      this.pageInfo = {};
      this.cursor = {
        after: null,
        before: null,
      };
    },
    handleProjectSelect(project) {
      this.resetPagination();
      this.selectedProject = project;
    },
    formatPath(paths) {
      return paths.map((path) => `${path.name} @${path.version}`).join(' / ');
    },
    nextPage(item) {
      this.cursor = {
        after: item,
        before: null,
      };
    },
    prevPage(item) {
      this.cursor = {
        after: null,
        before: item,
      };
    },
  },
  i18n: {
    drawerTitle: s__('Vulnerability|Dependency paths'),
    componentTitle: s__('Vulnerability|Component'),
    circularDependencyBadgeText: s__('Vulnerability|circular dependency'),
    maxDepthWarning: s__(
      'Vulnerability|Resolve the vulnerability in these dependencies to see additional paths. GitLab shows a maximum of 20 dependency paths per vulnerability.',
    ),
  },
  getContentWrapperHeight,
  DRAWER_Z_INDEX,
  truncateToggleButtonProps: {
    class: 'gl-text-subtle gl-mt-3',
  },
};
</script>

<template>
  <gl-drawer
    :header-height="$options.getContentWrapperHeight()"
    :open="showDrawer"
    :title="$options.i18n.drawerTitle"
    :z-index="$options.DRAWER_Z_INDEX"
    header-sticky
    @close="$emit('close')"
  >
    <template #title>
      <h4 data-testid="dependency-path-drawer-title" class="gl-my-0 gl-text-size-h2 gl-leading-24">
        {{ $options.i18n.drawerTitle }}
      </h4>
    </template>
    <template #header>
      <div class="gl-mt-3" data-testid="dependency-path-drawer-header">
        <strong>{{ $options.i18n.componentTitle }}:</strong>
        <span>{{ component.name }}</span>
        <span>{{ component.version }}</span>
      </div>
      <gl-collapsible-listbox
        v-if="showProjectDropdown"
        :selected="selectedProject"
        :items="projectItems"
        block
        class="gl-mt-5"
        @select="handleProjectSelect"
      >
        <template #list-item="{ item }">
          {{ item.text }}
        </template>
      </gl-collapsible-listbox>
    </template>
    <gl-skeleton-loader v-if="isLoading" />
    <div v-else>
      <ul class="gl-list-none gl-p-2">
        <li
          v-for="(dependencyPath, index) in localDependencyPaths"
          :key="index"
          class="gl-border-b gl-py-5 first:!gl-pt-0"
        >
          <gl-badge v-if="dependencyPath.isCyclic" variant="warning" class="mb-2">{{
            $options.i18n.circularDependencyBadgeText
          }}</gl-badge>
          <gl-truncate-text
            :toggle-button-props="$options.truncateToggleButtonProps"
            :mobile-lines="3"
          >
            <div class="gl-leading-20">
              {{ formatPath(dependencyPath.path) }}
            </div>
          </gl-truncate-text>
        </li>
      </ul>
      <div class="gl-mb-5 gl-flex gl-justify-center">
        <gl-keyset-pagination
          v-if="showPagination"
          v-bind="pageInfo"
          @prev="prevPage"
          @next="nextPage"
        />
      </div>
    </div>
    <template #footer>
      <gl-alert v-if="limitExceeded" :dismissible="false" variant="warning">
        {{ $options.i18n.maxDepthWarning }}
      </gl-alert>
    </template>
  </gl-drawer>
</template>

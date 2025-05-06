<script>
import {
  GlDrawer,
  GlTruncateText,
  GlBadge,
  GlAlert,
  GlCollapsibleListbox,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

export default {
  name: 'DependencyPathDrawer',
  components: {
    GlDrawer,
    GlTruncateText,
    GlBadge,
    GlAlert,
    GlCollapsibleListbox,
    GlSkeletonLoader,
  },
  props: {
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
      selectedProject: null,
      isLoading: false,
      loadingTimeout: null,
    };
  },
  computed: {
    showProjectDropdown() {
      return this.locations?.length > 0;
    },
    dependencyPathsList() {
      if (!this.showProjectDropdown) {
        return this.dependencyPaths;
      }

      if (this.isLoading) return [];
      return this.dropdownData.dependencyPathsLookup[this.selectedProject];
    },
    dropdownData() {
      const projectDropdown = [];
      const dependencyPathsLookup = {};

      this.locations.forEach((item) => {
        if (item.location.dependency_paths?.length > 0) {
          projectDropdown.push({
            value: item.value,
            text: item.project.name,
          });

          dependencyPathsLookup[item.value] = item.location.dependency_paths;
        }
      });

      return { projectDropdown, dependencyPathsLookup };
    },
  },
  created() {
    this.selectedProject = this.locations?.[0]?.value ?? null;
  },
  beforeDestroy() {
    if (this.loadingTimeout) {
      clearTimeout(this.loadingTimeout);
      this.loadingTimeout = null;
    }
  },
  methods: {
    formatPath(paths) {
      return paths.map((path) => `${path.name} @${path.version}`).join(' / ');
    },
    handleSelect(value) {
      this.isLoading = true;
      this.selectedProject = value;

      // Mimic loading time to help with visual feedback
      this.loadingTimeout = setTimeout(() => {
        this.isLoading = false;
      }, 300);
    },
  },
  i18n: {
    drawerTitle: s__('Vulnerability|Dependency paths'),
    projectTitle: s__('Vulnerability|Project'),
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
    </template>
    <gl-collapsible-listbox
      v-if="showProjectDropdown"
      :items="dropdownData.projectDropdown"
      :selected="selectedProject"
      block
      @select="handleSelect"
    >
      <template #list-item="{ item }">
        {{ item.text }}
      </template>
    </gl-collapsible-listbox>
    <gl-skeleton-loader v-if="isLoading" />
    <ul v-else class="gl-list-none gl-p-2">
      <li
        v-for="(dependencyPath, index) in dependencyPathsList"
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
    <template #footer>
      <gl-alert v-if="limitExceeded" :dismissible="false" variant="warning">
        {{ $options.i18n.maxDepthWarning }}
      </gl-alert>
    </template>
  </gl-drawer>
</template>

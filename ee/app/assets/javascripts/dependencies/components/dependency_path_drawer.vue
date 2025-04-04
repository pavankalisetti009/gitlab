<script>
import { GlDrawer, GlTruncateText, GlBadge, GlAlert } from '@gitlab/ui';
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
  },
  props: {
    dependencyPaths: {
      type: Array,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: () => {},
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
  },
  computed: {
    showProject() {
      return this.project && this.project.name;
    },
  },
  methods: {
    formatPath(paths) {
      return paths.map((path) => `${path.name} @${path.version}`).join(' / ');
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
    <div v-if="showProject" data-testid="dependency-path-drawer-project">
      <strong>{{ $options.i18n.projectTitle }}:</strong>
      <span>{{ project.name }}</span>
    </div>
    <ul class="gl-list-none gl-p-2">
      <li
        v-for="(dependencyPath, index) in dependencyPaths"
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

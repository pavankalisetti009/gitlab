<script>
import { GlDrawer } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

// This is temporary and will be deleted
// Will be replaced with proper API data once the BE completes
export const TEST_PATHS = [
  ['@jest@1.2.3', '@jest-internal-whatever@1.2.3', '@babel/core@7.47.7'],
  ['@react@0.13.1', '@babel/core@7.47.7'],
];

export default {
  name: 'DependencyPathDrawer',
  components: {
    GlDrawer,
  },
  props: {
    dependency: {
      type: Object,
      required: true,
    },
    showDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    showHeader() {
      return this.dependency?.name;
    },
    showProject() {
      return this.dependency.project?.name;
    },
  },
  i18n: {
    drawerTitle: s__('Vulnerability|Dependency paths'),
    projectTitle: s__('Vulnerability|Project'),
  },
  getContentWrapperHeight,
  DRAWER_Z_INDEX,
  TEST_PATHS,
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
    <template v-if="showHeader" #header>
      <div class="gl-mt-3" data-testid="dependency-path-drawer-header">
        <strong>{{ dependency.name }}</strong>
        <span class="gl-ml-2">{{ dependency.version }}</span>
      </div>
    </template>
    <div v-if="showProject" data-testid="dependency-path-drawer-project">
      <strong>{{ $options.i18n.projectTitle }}:</strong>
      <span>{{ dependency.project.name }}</span>
    </div>
    <ul class="gl-list-none gl-p-2">
      <li
        v-for="(path, index) in $options.TEST_PATHS"
        :key="index"
        class="gl-border-b gl-py-5 first:!gl-pt-0"
      >
        <div class="">{{ path.join(' / ') }}</div>
      </li>
    </ul>
  </gl-drawer>
</template>

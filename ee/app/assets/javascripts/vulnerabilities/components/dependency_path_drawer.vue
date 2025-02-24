<script>
import { MountingPortal } from 'portal-vue';
import { GlButton, GlDrawer } from '@gitlab/ui';
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
  name: 'DependencyPathsDrawer',
  components: {
    MountingPortal,
    GlButton,
    GlDrawer,
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  i18n: {
    buttonText: s__('Vulnerability|View dependency paths'),
    drawerTitle: s__('Vulnerability|Dependency paths'),
  },
  getContentWrapperHeight,
  DRAWER_Z_INDEX,
  TEST_PATHS,
};
</script>

<template>
  <div>
    <gl-button size="small" @click="openDrawer">{{ $options.i18n.buttonText }}</gl-button>
    <!-- Mount GlDrawer outside .md to fix z-index so it shows above navbar.
     More info: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181949#note_2360144489 -->
    <mounting-portal mount-to="#js-dependency-paths-drawer-portal">
      <gl-drawer
        :header-height="$options.getContentWrapperHeight()"
        :open="isDrawerOpen"
        :title="$options.i18n.drawerTitle"
        :z-index="$options.DRAWER_Z_INDEX"
        @close="closeDrawer"
      >
        <template #title>
          <h2
            data-testid="dependency-path-drawer-title"
            class="gl-my-0 gl-text-size-h2 gl-leading-24"
          >
            {{ $options.i18n.drawerTitle }}
          </h2>
        </template>
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
    </mounting-portal>
  </div>
</template>

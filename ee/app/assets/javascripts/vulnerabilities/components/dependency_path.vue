<script>
import { MountingPortal } from 'portal-vue';
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';

// This is temporary and will be deleted
// Will be replaced with proper API data once the BE completes
export const TEST_DEPENDENCY = {
  name: 'activerecord',
  version: '5.2.3',
  project: {
    name: 'gitlab-org/gitlab-ce',
  },
};

export default {
  name: 'DependencyPathsDrawer',
  components: {
    MountingPortal,
    GlButton,
    DependencyPathDrawer,
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  methods: {
    toggleDrawer() {
      this.isDrawerOpen = !this.isDrawerOpen;
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
  TEST_DEPENDENCY,
};
</script>

<template>
  <div>
    <gl-button size="small" @click="toggleDrawer">{{ $options.i18n.buttonText }}</gl-button>
    <!-- Mount GlDrawer outside .md to fix z-index so it shows above navbar.
     More info: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181949#note_2360144489 -->
    <mounting-portal mount-to="#js-dependency-paths-drawer-portal">
      <dependency-path-drawer
        :show-drawer="isDrawerOpen"
        :dependency="$options.TEST_DEPENDENCY"
        @close="closeDrawer"
      />
    </mounting-portal>
  </div>
</template>

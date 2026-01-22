<script>
import { GlDrawer } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import SecurityConfigurationProvider from '~/security_configuration/components/security_configuration_provider.vue';

export default {
  name: 'ProjectSecurityConfigurationDrawer',
  components: {
    GlDrawer,
    SecurityConfigurationProvider,
  },
  provide() {
    return {
      projectId: this.projectId,
      projectFullPath: this.projectFullPath,
    };
  },
  props: {
    projectId: {
      type: String,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    projectName: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    drawerTitle() {
      return this.projectName
        ? sprintf(s__('SecurityInventory|Security configuration: %{projectName}'), {
            projectName: this.projectName,
          })
        : s__('SecurityInventory|Security configuration');
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="isDrawerOpen"
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    size="lg"
    style="width: 90%"
    @close="closeDrawer"
  >
    <template #title>
      <h2 class="gl-font-size-h2 gl-m-0">
        {{ drawerTitle }}
      </h2>
    </template>
    <template #default>
      <security-configuration-provider v-if="isDrawerOpen" />
    </template>
  </gl-drawer>
</template>

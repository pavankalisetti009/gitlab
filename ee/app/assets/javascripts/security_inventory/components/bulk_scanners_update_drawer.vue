<script>
import { GlDrawer, GlSprintf } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import BulkScannerProfileConfiguration from './bulk_scanner_profile_configuration.vue';

export default {
  name: 'BulkScannersUpdateDrawer',
  components: {
    GlDrawer,
    GlSprintf,
    BulkScannerProfileConfiguration,
  },
  inject: ['groupFullPath'],
  props: {
    itemIds: {
      type: Array,
      required: false,
      default: () => [],
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
    class="!gl-w-[100cqw] !gl-max-w-5xl"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="closeDrawer"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">
        <gl-sprintf
          :message="
            n__(
              'SecurityInventory|Edit security scanners for %d item',
              'SecurityInventory|Edit security scanners for %d items',
              itemIds.length,
            )
          "
        >
          <template #itemCount>{{ itemIds.length }}</template>
        </gl-sprintf>
      </h4>
    </template>

    <bulk-scanner-profile-configuration />
  </gl-drawer>
</template>

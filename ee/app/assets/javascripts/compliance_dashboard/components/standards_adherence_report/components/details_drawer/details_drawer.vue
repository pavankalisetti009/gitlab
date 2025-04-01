<script>
import { GlDrawer } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import FrameworkBadge from '../../../shared/framework_badge.vue';

export default {
  components: {
    GlDrawer,

    FrameworkBadge,
  },
  props: {
    status: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    title() {
      return this.status?.complianceRequirement.name || '';
    },
  },
  methods: {
    getContentWrapperHeight,
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <gl-drawer
    :open="Boolean(status)"
    :header-height="getContentWrapperHeight()"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template #title>
      <h2 class="gl-heading-3 gl-mb-0">{{ title }}</h2>
    </template>
    <template v-if="status">
      <div class="gl-flex gl-flex-row gl-gap-3 gl-p-5">
        <framework-badge :framework="status.complianceFramework" popover-mode="details" />
      </div>
    </template>
  </gl-drawer>
</template>

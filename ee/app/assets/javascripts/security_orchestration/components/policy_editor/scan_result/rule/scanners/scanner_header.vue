<script>
import { GlButton } from '@gitlab/ui';
import { getCollapseIcon } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';

export default {
  name: 'ScannerHeader',
  components: {
    GlButton,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    visible: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle'],
  computed: {
    collapseIcon() {
      return getCollapseIcon(this.visible);
    },
  },
};
</script>

<template>
  <div class="gl-flex" :class="{ 'gl-mb-3': visible }">
    <gl-button
      category="tertiary"
      :aria-label="collapseIcon"
      :icon="collapseIcon"
      @click="$emit('toggle')"
    />
    <h5>{{ title }}</h5>
  </div>
</template>

<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { getCollapseIcon } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';

export default {
  i18n: {
    ariaLabel: __('Remove'),
  },
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
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['toggle', 'remove'],
  computed: {
    collapseIcon() {
      return getCollapseIcon(this.visible);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-justify-between" :class="{ 'gl-mb-3': visible }">
    <div class="gl-flex gl-items-center">
      <gl-button
        category="tertiary"
        :aria-label="collapseIcon"
        :icon="collapseIcon"
        @click="$emit('toggle')"
      />
      <h5 class="gl-m-0">{{ title }}</h5>
    </div>
    <gl-button
      v-if="showRemoveButton"
      icon="remove"
      category="tertiary"
      :aria-label="$options.i18n.ariaLabel"
      data-testid="remove-scanner"
      @click="$emit('remove')"
    />
  </div>
</template>

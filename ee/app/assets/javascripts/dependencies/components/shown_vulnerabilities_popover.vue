<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

export default {
  name: 'ShownVulnerabilitiesPopover',
  components: {
    LocalStorageSync,
    GlBadge,
    GlPopover,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      popoverDismissed: false,
    };
  },
  computed: {
    shouldShowPopover() {
      return (
        this.glFeatures.hideNoLongerDetectedVulnerabilitiesOnTheDependencyList &&
        !this.popoverDismissed
      );
    },
  },
  methods: {
    setPopoverDismissed(value) {
      this.popoverDismissed = value;
    },
  },
};
</script>

<template>
  <local-storage-sync
    :value="popoverDismissed"
    storage-key="dl-shown-vulnerabilities-popover-disabled"
    @input="setPopoverDismissed"
  >
    <gl-popover
      v-if="shouldShowPopover"
      :show-close-button="true"
      placement="bottom"
      boundary="viewport"
      target="vulnerabilities-header"
      @close-button-clicked="setPopoverDismissed(true)"
    >
      <template #title>
        <div class="gl-flex gl-items-center gl-justify-between gl-gap-3">
          {{ __('Focused vulnerability reporting') }}
          <gl-badge variant="info" size="small" target="_blank">
            {{ __('New') }}
          </gl-badge>
        </div>
      </template>
      <template #default>
        <p class="gl-mb-0">
          {{
            __(`The dependency list now only shows vulnerabilities that are still detected in the project.\
Previously, vulnerabilities were shown regardless of their status.\
We've updated this to provide a more accurate risk assessment of each component.`)
          }}
        </p>
      </template>
    </gl-popover>
  </local-storage-sync>
</template>

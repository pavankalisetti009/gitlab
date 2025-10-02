<script>
import { GlBadge, GlPopover, GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

export default {
  name: 'ShownVulnerabilitiesPopover',
  components: {
    LocalStorageSync,
    GlBadge,
    GlPopover,
    GlIcon,
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
  <div>
    <gl-icon id="vulnerabilities-info" name="information-o" class="gl-ml-2" variant="info" />
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
        target="vulnerabilities-info"
        @close-button-clicked="setPopoverDismissed(true)"
      >
        <template #title>
          <gl-badge variant="info" size="small" target="_blank">
            {{ __('New') }}
          </gl-badge>
          <div class="gl-flex gl-items-center gl-justify-between gl-gap-3">
            {{ __('Focused vulnerability reporting') }}
          </div>
        </template>
        <template #default>
          <p class="gl-mb-0">
            {{
              __(
                `The dependency list now excludes vulnerabilities that are no longer detected in the project. \
              Removing these vulnerabilities gives you a more accurate risk assessment of each component.`,
              )
            }}
          </p>
        </template>
      </gl-popover>
    </local-storage-sync>
  </div>
</template>

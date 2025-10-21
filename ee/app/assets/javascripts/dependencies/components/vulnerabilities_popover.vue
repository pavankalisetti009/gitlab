<script>
import { GlButton, GlIcon, GlPopover } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { __, s__ } from '~/locale';

export default {
  name: 'VulnerabilitiesPopover',
  components: {
    LocalStorageSync,
    GlButton,
    GlIcon,
    GlPopover,
  },
  props: {},
  data() {
    return {
      popoverDismissed: false,
    };
  },
  computed: {
    showPopover() {
      return !this.popoverDismissed;
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
    <div>
      <gl-icon id="vulnerabilities-info" name="information-o" class="gl-ml-2" variant="info" />
      <gl-popover
        placement="bottom"
        boundary="viewport"
        target="vulnerabilities-info"
        data-testid="vulnerability-info-popover"
        :show="showPopover"
        :title="s__('Dependencies|Focused vulnerability reporting')"
      >
        <p class="gl-mb-0">
          {{
            s__(
              'Dependencies|The dependency list shows only active, currently detected issues. Vulnerabilities that are no longer detected are filtered out.',
            )
          }}
        </p>
        <div class="gl-text-righ t gl-mt-3">
          <gl-button
            v-if="showPopover"
            data-testid="dismiss-button"
            category="primary"
            variant="confirm"
            @click="setPopoverDismissed(true)"
          >
            {{ __("Don't show again") }}
          </gl-button>
        </div>
      </gl-popover>
    </div>
  </local-storage-sync>
</template>

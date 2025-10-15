<script>
import { GlButton, GlIcon, GlPopover } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { DEPENDENCIES_TABLE_I18N } from '../constants';

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
  i18n: DEPENDENCIES_TABLE_I18N,
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
        :title="$options.i18n.vulnerabilityInfoTitle"
      >
        <p class="gl-mb-0">{{ $options.i18n.vulnerabilityInfoBody }}</p>
        <div class="gl-mt-3 gl-text-right">
          <gl-button
            v-if="showPopover"
            data-testid="dismiss-button"
            category="primary"
            variant="confirm"
            @click="setPopoverDismissed(true)"
          >
            {{ $options.i18n.vulnerabilityInfoDismissButtonText }}
          </gl-button>
        </div>
      </gl-popover>
    </div>
  </local-storage-sync>
</template>

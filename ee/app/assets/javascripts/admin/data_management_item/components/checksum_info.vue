<script>
import { GlSprintf, GlBadge, GlCard, GlButton } from '@gitlab/ui';
import { VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

export default {
  name: 'ChecksumInfo',
  components: {
    GlSprintf,
    GlBadge,
    GlButton,
    GlCard,
    TimeAgo,
    ClipboardButton,
  },
  props: {
    details: {
      type: Object,
      required: true,
    },
    checksumLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    checksumStatus() {
      const checksumState = this.details.checksumState?.toUpperCase();
      return VERIFICATION_STATUS_STATES[checksumState] || VERIFICATION_STATUS_STATES.UNKNOWN;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ s__('Geo|Checksum information') }}</h5>
    </template>

    <div class="gl-flex gl-flex-col gl-items-start gl-gap-4">
      <p class="gl-mb-0" data-testid="checksum-status">
        <gl-sprintf :message="s__('Geo|Status: %{badge}')">
          <template #badge>
            <gl-badge :variant="checksumStatus.variant">{{ checksumStatus.title }}</gl-badge>
          </template>
        </gl-sprintf>
      </p>

      <template v-if="details.checksumFailure">
        <p class="gl-mb-0" data-testid="checksum-failure">
          <gl-sprintf :message="s__('Geo|Error: %{message}')">
            <template #message>
              <span class="gl-font-bold gl-text-danger">{{ details.checksumFailure }}</span>
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0 gl-font-bold" data-testid="checksum-retry">
          <gl-sprintf
            :message="
              s__(
                'Geo|%{noBoldStart}Next checksum retry:%{noBoldEnd} Retry #%{retryCount} scheduled %{timeAgo}',
              )
            "
          >
            <template #noBold="{ content }">
              <span class="gl-font-normal">{{ content }}</span>
            </template>
            <template #retryCount>
              <span>{{ details.retryCount }}</span>
            </template>
            <template #timeAgo>
              <time-ago :time="details.retryAt" />
            </template>
          </gl-sprintf>
        </p>
      </template>

      <p v-if="details.lastChecksum" data-testid="checksum-last" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Last checksum: %{timeAgo}')">
          <template #timeAgo>
            <time-ago :time="details.lastChecksum" class="gl-font-bold" />
          </template>
        </gl-sprintf>
      </p>

      <p data-testid="checksum" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Checksum: %{checksum}')">
          <template #checksum>
            <span class="gl-font-bold">{{ details.checksum || __('Unknown') }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          v-if="details.checksum"
          :title="__('Copy')"
          :text="details.checksum"
          size="small"
          category="tertiary"
        />
      </p>

      <gl-button :loading="checksumLoading" @click="$emit('recalculate-checksum')">{{
        s__('Geo|Checksum')
      }}</gl-button>
    </div>
  </gl-card>
</template>

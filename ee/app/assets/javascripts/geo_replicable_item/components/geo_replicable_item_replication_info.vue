<script>
import { GlSprintf, GlBadge, GlCard } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { REPLICATION_STATUS_STATES } from '../constants';

export default {
  name: 'GeoReplicableItemReplicationInfo',
  components: {
    GlSprintf,
    GlBadge,
    GlCard,
    TimeAgo,
  },
  props: {
    replicableItem: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    replicationInformation: s__('Geo|Replication information'),
    missingOnPrimary: s__('Geo|Missing on Primary!'),
    lastSyncedAt: s__('Geo|Last synced: %{timeAgo}'),
    syncRetryAt: s__(
      'Geo|%{noBoldStart}Next sync retry:%{noBoldEnd} Retry #%{retryCount} scheduled %{timeAgo}',
    ),
    statusBadge: s__('Geo|Status: %{badge}'),
    geoFailure: s__('Geo|Error: %{message}'),
    unknown: __('Unknown'),
  },
  computed: {
    replicationStatus() {
      return (
        REPLICATION_STATUS_STATES[this.replicableItem?.state] || REPLICATION_STATUS_STATES.UNKNOWN
      );
    },
    replicationFailure() {
      return this.replicableItem?.state === REPLICATION_STATUS_STATES.FAILED.value;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.replicationInformation }}</h5>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.statusBadge">
          <template #badge>
            <gl-badge :variant="replicationStatus.variant">{{ replicationStatus.title }}</gl-badge>
          </template>
        </gl-sprintf>
      </p>

      <p v-if="replicableItem.missingOnPrimary" class="gl-mb-0 gl-font-bold gl-text-red-700">
        {{ $options.i18n.missingOnPrimary }}
      </p>

      <template v-if="replicationFailure">
        <p class="gl-mb-0">
          <gl-sprintf :message="$options.i18n.geoFailure">
            <template #message>
              <span class="gl-font-bold gl-text-red-700">{{
                replicableItem.lastSyncFailure || $options.i18n.unknown
              }}</span>
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0 gl-font-bold">
          <gl-sprintf :message="$options.i18n.syncRetryAt">
            <template #noBold="{ content }">
              <span class="gl-font-normal">{{ content }}</span>
            </template>
            <template #retryCount>
              <span>{{ replicableItem.retryCount }}</span>
            </template>
            <template #timeAgo>
              <time-ago :time="replicableItem.retryAt" data-testid="retry-at-time-ago" />
            </template>
          </gl-sprintf>
        </p>
      </template>

      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.lastSyncedAt">
          <template #timeAgo>
            <time-ago
              :time="replicableItem.lastSyncedAt"
              class="gl-font-bold"
              data-testid="last-synced-at-time-ago"
            />
          </template>
        </gl-sprintf>
      </p>
    </div>
  </gl-card>
</template>

<script>
import { sprintf } from '@gitlab/ui/src/utils/i18n';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { __, s__ } from '~/locale';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { VERIFICATION_STATUS_LABELS, VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';

export default {
  i18n: {
    created: __('Created'),
    unknown: __('Unknown'),
    lastChecksum: s__('Geo|Last checksum'),
  },
  components: {
    GeoListItem,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    timeAgoArray() {
      return [
        {
          label: this.$options.i18n.created,
          dateString: this.item.createdAt,
          defaultText: this.$options.i18n.unknown,
        },
        {
          label: this.$options.i18n.lastChecksum,
          dateString: this.item.checksumInformation?.lastChecksum,
          defaultText: this.$options.i18n.unknown,
        },
      ];
    },
    statusArray() {
      const state = this.item.checksumInformation?.checksumState?.toUpperCase();
      const status = VERIFICATION_STATUS_STATES[state] || VERIFICATION_STATUS_STATES.UNKNOWN;
      const label = VERIFICATION_STATUS_LABELS[state] || VERIFICATION_STATUS_LABELS.UNKNOWN;

      return [
        {
          tooltip: sprintf(s__('Geo|Checksum: %{status}'), { status: status.title }),
          icon: status.icon,
          variant: status.variant,
          label,
        },
      ];
    },
    name() {
      return `${this.item.modelClass}/${this.item.recordIdentifier}`;
    },
    size() {
      const { fileSize } = this.item;
      const hasFileSize = fileSize != null;

      return sprintf(s__('Geo|Storage: %{size}'), {
        size: hasFileSize ? numberToHumanSize(fileSize) : this.$options.i18n.unknown,
      });
    },
  },
};
</script>

<template>
  <geo-list-item :name="name" :time-ago-array="timeAgoArray" :status-array="statusArray">
    <template #extra-details>{{ size }}</template>
  </geo-list-item>
</template>

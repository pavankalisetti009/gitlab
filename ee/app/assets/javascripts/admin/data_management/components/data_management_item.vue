<script>
import { sprintf } from '@gitlab/ui/src/utils/i18n';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { __, s__ } from '~/locale';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { ACTION_TYPES } from 'ee/admin/data_management/constants';
import { createAlert } from '~/alert';
import { putModelAction } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import showToast from '~/vue_shared/plugins/global_toast';
import { VERIFICATION_STATUS_LABELS, VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';

export default {
  i18n: {
    created: __('Created'),
    unknown: __('Unknown'),
    checksum: s__('Geo|Checksum'),
    lastChecksum: s__('Geo|Last checksum'),
  },
  components: {
    GeoListItem,
  },
  props: {
    modelName: {
      type: String,
      required: true,
    },
    initialItem: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      item: this.initialItem,
      actionLoading: {},
    };
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
    actionsArray() {
      return [
        {
          id: 'geo-checksum-item',
          value: ACTION_TYPES.CHECKSUM,
          text: this.$options.i18n.checksum,
          loading: this.actionLoading[ACTION_TYPES.CHECKSUM] ?? false,
          successMessage: sprintf(s__('Geo|Successfully recalculated checksum for %{name}.'), {
            name: this.name,
          }),
          errorMessage: sprintf(s__('Geo|There was an error recalculating checksum for %{name}.'), {
            name: this.name,
          }),
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
  methods: {
    setActionLoading(action, value) {
      this.actionLoading = { ...this.actionLoading, [action]: value };
    },
    async handleSingleAction({ value, successMessage, errorMessage }) {
      this.setActionLoading(value, true);

      try {
        const { data } = await putModelAction(this.modelName, this.item.recordIdentifier, value);

        this.item = convertObjectPropsToCamelCase(data, { deep: true });

        showToast(successMessage);
      } catch (error) {
        createAlert({ message: errorMessage, captureError: true, error });
      } finally {
        this.setActionLoading(value, false);
      }
    },
  },
};
</script>

<template>
  <geo-list-item
    :name="name"
    :time-ago-array="timeAgoArray"
    :status-array="statusArray"
    :actions-array="actionsArray"
    @actionClicked="handleSingleAction"
  >
    <template #extra-details>{{ size }}</template>
  </geo-list-item>
</template>

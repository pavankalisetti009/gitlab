<script>
import { GlAvatar, GlTable } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlAvatar,
    GlTable,
  },
  props: {
    usageData: {
      type: Array,
      required: true,
    },
  },
  computed: {
    tableFields() {
      return [
        {
          key: 'namespace',
          label: s__('UsageQuota|Namespace'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center sm:gl-table-cell',
        },
        {
          key: 'hostedRunnerDuration',
          label: s__('UsageQuota|Hosted runner duration'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center gl-content-center sm:gl-table-cell',
        },
        {
          key: 'computeUsage',
          label: s__('UsageQuota|Compute usage'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center gl-content-center sm:gl-table-cell',
        },
      ];
    },
  },
};
</script>
<template>
  <gl-table
    thead-class="gl-border-b-solid gl-border-default gl-border-1"
    :fields="tableFields"
    :items="usageData"
    stacked="md"
    fixed
  >
    <template
      #cell(namespace)="{
        item: {
          rootNamespace: { avatarUrl, name },
        },
      }"
    >
      <div class="gl-flex gl-items-center">
        <gl-avatar :src="avatarUrl" :size="32" />
        <span class="gl-ml-4">{{ name }}</span>
      </div>
    </template>
    <template #cell(hostedRunnerDuration)="{ item: { durationSeconds } }">
      <span data-testid="runner-duration">{{ durationSeconds }}</span>
    </template>
    <template #cell(computeUsage)="{ item: { computeMinutes } }">
      <span data-testid="compute-minutes">{{ computeMinutes }}</span>
    </template>
  </gl-table>
</template>

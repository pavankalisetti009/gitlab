<script>
import { GlLink, GlTable } from '@gitlab/ui';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';

export default {
  name: 'EventsTable',
  components: {
    GlLink,
    GlTable,
    UserDate,
  },
  props: {
    events: {
      type: Array,
      required: true,
    },
  },
  computed: {
    tableFields() {
      return [
        { key: 'timestamp', label: s__('UsageBilling|Date and time') },
        { key: 'eventType', label: s__('UsageBilling|Action') },
        { key: 'location', label: s__('UsageBilling|Location') },
        { key: 'unitsUsed', label: s__('UsageBilling|Unit amount') },
      ];
    },
  },
  SHORT_DATE_FORMAT_WITH_TIME,
};
</script>
<template>
  <div>
    <gl-table :fields="tableFields" :items="events">
      <template #cell(timestamp)="{ item }">
        <user-date :date="item.timestamp" :date-format="$options.SHORT_DATE_FORMAT_WITH_TIME" />
      </template>

      <template #cell(location)="{ item }">
        <gl-link v-if="item.location" :href="item.location.web_url">
          {{ item.location.name }}
        </gl-link>
      </template>
    </gl-table>
  </div>
</template>

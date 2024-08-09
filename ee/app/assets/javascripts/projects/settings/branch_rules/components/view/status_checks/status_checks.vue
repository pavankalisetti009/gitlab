<script>
import StatusChecksTable from './status_checks_table.vue';
import StatusChecksDrawer from './status_checks_drawer.vue';

export default {
  name: 'StatusChecks',
  components: {
    StatusChecksTable,
    StatusChecksDrawer,
  },
  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isStatusChecksDrawerOpen: false,
    };
  },
};
</script>

<template>
  <div>
    <status-checks-table
      :status-checks="statusChecks"
      data-testid="status-checks-table"
      @add="isStatusChecksDrawerOpen = true"
      @edit="isStatusChecksDrawerOpen = true"
    />
    <status-checks-drawer
      :is-open="isStatusChecksDrawerOpen"
      :is-loading="false"
      :status-checks="statusChecks"
      data-testid="status-checks-drawer"
      @close="isStatusChecksDrawerOpen = false"
      @saveChanges="$emit('saveChanges')"
    />
  </div>
</template>

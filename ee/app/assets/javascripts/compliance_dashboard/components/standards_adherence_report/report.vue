<script>
import ComplianceStandardsAdherenceTable from './standards_adherence_table.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTable,
  },
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <compliance-standards-adherence-table :group-path="groupPath" :project-path="projectPath" />
</template>

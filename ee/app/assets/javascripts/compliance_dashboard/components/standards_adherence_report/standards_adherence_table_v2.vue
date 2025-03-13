<script>
import { s__ } from '~/locale';
import AdherencesBaseTable from './base_table.vue';

export default {
  name: 'ComplianceStandardsAdherenceTableV2',
  components: {
    AdherencesBaseTable,
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
  data() {
    return {
      filters: {},
    };
  },
  computed: {},
  methods: {},
  i18n: {
    newReport: s__('ComplianceStandardsAdherenceV2|New Report Placeholder'),
  },
};
</script>

<template>
  <section>
    <div class="gl-mt-3 gl-bg-alpha-dark-6 gl-p-4">
      <h2>{{ $options.i18n.newReport }}</h2>
    </div>
    <adherences-base-table :group-path="groupPath" :filters="filters" :project-path="projectPath" />
  </section>
</template>

<style></style>

<script>
import { s__ } from '~/locale';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';

export default {
  name: 'SecurityFindingsPage',
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      enabledScans: {
        full: {},
        partial: {},
      },
      errorMessage: '',
    };
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.targetProjectFullPath,
          pipelineIid: this.pipelineIid,
        };
      },
      update({ project }) {
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        return {
          full: project.pipeline.enabledSecurityScans || {},
          partial: project.pipeline.enabledPartialSecurityScans || {},
        };
      },
      error() {
        this.errorMessage = s__(
          'ciReport|Error while fetching enabled scans. Please try again later.',
        );
      },
      skip() {
        return !this.pipelineIid || !this.targetProjectFullPath;
      },
    },
  },
  computed: {
    pipelineIid() {
      return this.mr.pipeline?.iid;
    },
    targetProjectFullPath() {
      return this.mr.targetProjectFullPath;
    },
    isLoading() {
      return this.$apollo.queries.enabledScans.loading;
    },
    hasEnabledScans() {
      const isEnabled = (scans) =>
        Object.entries(scans)
          .filter(([key]) => key !== 'ready' && key !== '__typename')
          .some(([, value]) => value === true);

      return isEnabled(this.enabledScans.full) || isEnabled(this.enabledScans.partial);
    },
  },
};
</script>

<template>
  <div data-testid="security-findings-page">
    <template v-if="errorMessage">
      {{ errorMessage }}
    </template>
    <template v-else-if="isLoading">
      {{ isLoading }}
    </template>
    <template v-else>{{ hasEnabledScans }}</template>
  </div>
</template>

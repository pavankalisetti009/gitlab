<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';

export default {
  name: 'ComplianceViolationDetailsApp',
  components: {
    GlLoadingIcon,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      complianceViolation: {},
    };
  },
  apollo: {
    complianceViolation: {
      query: complianceViolationQuery,
      variables() {
        return {
          id: this.violationId,
        };
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.complianceViolation.loading;
    },
    title() {
      if (!this.complianceViolation) return '';
      return sprintf(__('Details of vio-%{violationId}'), {
        violationId: this.complianceViolation.id,
      });
    },
  },
  i18n: {
    status: __('Status'),
    location: __('Location'),
  },
};
</script>
<template>
  <gl-loading-icon
    v-if="isLoading"
    data-testid="compliance-violation-details-loading-status"
    class="gl-mt-5"
  />
  <div v-else data-testid="compliance-violation-details">
    <h1 class="page-title gl-text-size-h-display" data-testid="compliance-violation-title">
      {{ title }}
    </h1>
    <div class="gl-mt-5" data-testid="compliance-violation-status">
      <span class="gl-font-bold">{{ $options.i18n.status }}:</span> {{ complianceViolation.status }}
    </div>
    <div class="gl-mt-4">
      <span class="gl-font-bold">{{ $options.i18n.location }}:</span>
      <a
        :href="complianceViolation.project.webUrl"
        data-testid="compliance-violation-location-link"
      >
        {{ complianceViolation.project.nameWithNamespace }}
      </a>
    </div>
  </div>
</template>

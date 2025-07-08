<script>
import { GlLoadingIcon, GlToast } from '@gitlab/ui';
import Vue from 'vue';
import { __, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import updateComplianceViolationStatus from '../graphql/mutations/update_compliance_violation_status.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import AuditEvent from './audit_event.vue';
import FixSuggestionSection from './fix_suggestion_section.vue';
import ViolationSection from './violation_section.vue';

Vue.use(GlToast);

export default {
  name: 'ComplianceViolationDetailsApp',
  components: {
    AuditEvent,
    ComplianceViolationStatusDropdown,
    FixSuggestionSection,
    GlLoadingIcon,
    ViolationSection,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    complianceCenterPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      complianceViolation: {},
      isStatusUpdating: false,
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
        violationId: getIdFromGraphQLId(this.complianceViolation.id),
      });
    },
  },
  methods: {
    async handleStatusChange(newStatus) {
      this.isStatusUpdating = true;
      try {
        await this.$apollo.mutate({
          mutation: updateComplianceViolationStatus,
          variables: {
            input: {
              violationId: this.violationId,
              status: newStatus,
            },
          },
        });
      } catch (error) {
        this.$toast.show(this.$options.i18n.statusUpdateError, {
          variant: 'danger',
        });
      } finally {
        this.isStatusUpdating = false;
      }
    },
  },
  i18n: {
    status: __('Status'),
    location: __('Location'),
    statusUpdateError: __('Failed to update compliance violation status. Please try again later.'),
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
      <span class="gl-font-bold">{{ $options.i18n.status }}:</span>
      <compliance-violation-status-dropdown
        class="gl-ml-3 gl-align-baseline"
        :value="complianceViolation.status.toLowerCase()"
        :loading="isStatusUpdating"
        @change="handleStatusChange"
      />
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
    <audit-event
      v-if="complianceViolation.auditEvent"
      class="gl-mt-5"
      :audit-event="complianceViolation.auditEvent"
    />
    <violation-section
      class="gl-mt-5"
      :control="complianceViolation.complianceControl"
      :compliance-center-path="complianceCenterPath"
    />
    <fix-suggestion-section
      class="gl-mt-5"
      :control-id="complianceViolation.complianceControl.id"
      :project-path="complianceViolation.project.webUrl"
    />
  </div>
</template>

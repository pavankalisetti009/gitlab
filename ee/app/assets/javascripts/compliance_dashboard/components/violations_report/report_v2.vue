<script>
import { GlAlert, GlLoadingIcon, GlTable, GlLink, GlToast, GlKeysetPagination } from '@gitlab/ui';
import Vue from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import ComplianceFrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import groupComplianceViolationsQuery from 'ee/compliance_violations/graphql/compliance_violations.query.graphql';
import updateComplianceViolationStatus from 'ee/compliance_violations/graphql/mutations/update_compliance_violation_status.mutation.graphql';

Vue.use(GlToast);

export const VIOLATION_PAGE_SIZE = 20;

export default {
  name: 'ComplianceViolationsReportV2',
  components: {
    GlAlert,
    GlLoadingIcon,
    GlTable,
    GlLink,
    GlKeysetPagination,
    ComplianceViolationStatusDropdown,
    ComplianceFrameworkBadge,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      queryError: false,
      violations: { nodes: [] },
      isStatusUpdating: false,
      cursor: {
        before: null,
        after: null,
      },
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.violations.loading;
    },
    emptyText() {
      return this.$options.i18n.noViolationsFound;
    },
  },
  methods: {
    onPrevPage() {
      this.cursor = {
        before: this.violations.pageInfo.startCursor,
        after: null,
      };
    },

    onNextPage() {
      this.cursor = {
        after: this.violations.pageInfo.endCursor,
        before: null,
      };
    },

    async handleStatusChange(newStatus, violation) {
      this.isStatusUpdating = true;
      try {
        await this.$apollo.mutate({
          mutation: updateComplianceViolationStatus,
          variables: {
            input: {
              violationId: violation.id,
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
    getFormattedDate(dateString) {
      return formatDate(dateString, ISO_SHORT_FORMAT, true);
    },
    getViolationDetailsPath(violation) {
      if (!violation || !violation.id) {
        return '#';
      }

      if (!violation.project) {
        return '#';
      }

      const projectPath = violation.project.fullPath || violation.project.path_with_namespace;
      if (!projectPath) {
        return '#';
      }

      try {
        const violationId = getIdFromGraphQLId(violation.id);
        if (!violationId) {
          return '#';
        }

        return `/${projectPath}/-/security/compliance_violations/${violationId}`;
      } catch (error) {
        return '#';
      }
    },
  },
  apollo: {
    violations: {
      query: groupComplianceViolationsQuery,
      variables() {
        return {
          fullPath: this.groupPath,
          ...this.cursor,
          [this.cursor.before ? 'last' : 'first']: VIOLATION_PAGE_SIZE,
        };
      },
      update(data) {
        return data?.group?.projectComplianceViolations;
      },
      error(e) {
        Sentry.captureException(e);
        this.queryError = true;
      },
    },
  },
  fields: [
    {
      key: 'status',
      label: __('Status'),
      thClass: 'gl-w-1/6 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: true,
    },
    {
      key: 'complianceControl',
      label: s__('ComplianceReport|Violated control and framework'),
      thClass: 'gl-w-1/4 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: true,
    },
    {
      key: 'auditEvent',
      label: s__('ComplianceReport|Audit Event'),
      thClass: 'gl-w-1/4 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'project',
      label: __('Project'),
      thClass: 'gl-w-1/6 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: true,
    },
    {
      key: 'createdAt',
      label: s__('ComplianceReport|Date detected'),
      thClass: 'gl-w-1/8 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: true,
    },
    {
      key: 'actions',
      label: s__('ComplianceReport|Action'),
      thClass: 'gl-w-1/8 !gl-p-5',
      tdClass: '!gl-align-middle',
      sortable: false,
    },
  ],
  i18n: {
    queryError: s__(
      'ComplianceReport|Unable to load the compliance violations report. Refresh the page and try again.',
    ),
    noViolationsFound: s__('ComplianceReport|No violations found'),
    statusUpdateError: s__('ComplianceReport|Failed to update violation status. Please try again.'),
    viewDetails: s__('ComplianceReport|Details'),
    changeStatus: s__('ComplianceReport|Change status'),
  },
};
</script>

<template>
  <section class="gl-flex gl-flex-col">
    <gl-alert v-if="queryError" variant="danger" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.queryError }}
    </gl-alert>

    <gl-table
      ref="table"
      :fields="$options.fields"
      :items="violations.nodes"
      :busy="isLoading"
      :empty-text="emptyText"
      show-empty
      stacked="lg"
      hover
      class="compliance-violations-table"
    >
      <template #cell(status)="{ item }">
        <div class="gl-mt-5" data-testid="compliance-violation-status">
          <compliance-violation-status-dropdown
            class="gl-ml-3 gl-align-baseline"
            :value="item.status.toLowerCase()"
            :loading="isStatusUpdating"
            @change="(newStatus) => handleStatusChange(newStatus, item)"
          />
        </div>
      </template>

      <template #cell(complianceControl)="{ item }">
        <div class="gl-font-weight-semibold gl-mb-2">{{ item.complianceControl.name }}</div>
        <compliance-framework-badge
          v-if="
            item.complianceControl.complianceRequirement &&
            item.complianceControl.complianceRequirement.framework
          "
          :framework="item.complianceControl.complianceRequirement.framework"
          popover-mode="details"
        />
      </template>

      <template #cell(auditEvent)="{}">
        <div>
          <div class="gl-font-weight-semibold gl-mb-2">
            {{ __('Audit Event Details placeholder') }}
          </div>
          <div class="gl-text-sm gl-text-secondary">{{ __('Audit Event Author Placeholder') }}</div>
        </div>
      </template>

      <template #cell(project)="{ item }">
        <div class="gl-font-weight-semibold">{{ item.project.name }}</div>
      </template>

      <template #cell(createdAt)="{ item }">
        {{ getFormattedDate(item.createdAt) }}
      </template>

      <template #cell(actions)="{ item }">
        <gl-link class="gl-cursor-pointer gl-text-blue-500" :href="getViolationDetailsPath(item)">
          {{ $options.i18n.viewDetails }}
        </gl-link>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
    </gl-table>

    <gl-keyset-pagination
      v-bind="violations.pageInfo"
      class="gl-mt-7 gl-self-center"
      @prev="onPrevPage"
      @next="onNextPage"
    />
  </section>
</template>

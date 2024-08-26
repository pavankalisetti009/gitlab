<script>
import { GlAlert, GlCollapse, GlEmptyState, GlFormCheckbox, GlPagination } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import SecurityDashboardTableRow from './security_dashboard_table_row.vue';
import SelectionSummary from './selection_summary_vuex.vue';

export default {
  name: 'SecurityDashboardTable',
  components: {
    GlAlert,
    GlCollapse,
    GlEmptyState,
    GlFormCheckbox,
    GlPagination,
    SecurityDashboardTableRow,
    SelectionSummary,
  },
  inject: ['canAdminVulnerability'],
  computed: {
    ...mapState('vulnerabilities', [
      'errorLoadingVulnerabilities',
      'errorLoadingVulnerabilitiesCount',
      'isLoadingVulnerabilities',
      'isDismissingVulnerabilities',
      'pageInfo',
      'vulnerabilities',
    ]),
    ...mapState('filters', ['filters']),
    ...mapGetters('vulnerabilities', [
      'dashboardListError',
      'hasSelectedAllVulnerabilities',
      'isSelectingVulnerabilities',
    ]),
    showEmptyState() {
      return (
        this.vulnerabilities &&
        !this.vulnerabilities.length &&
        !this.errorLoadingVulnerabilities &&
        !this.errorLoadingVulnerabilitiesCount
      );
    },
    showCompactPagination() {
      return Boolean(this.pageInfo?.page);
    },
    currentPage() {
      return this.pageInfo.page;
    },
    nextPage() {
      return this.pageInfo.nextPage;
    },
    previousPage() {
      return this.pageInfo.previousPage;
    },
  },
  methods: {
    ...mapActions('vulnerabilities', [
      'deselectAllVulnerabilities',
      'fetchVulnerabilities',
      'selectAllVulnerabilities',
    ]),
    fetchPage(page) {
      this.fetchVulnerabilities({ ...this.filters, page });
    },
    handleSelectAll() {
      return this.hasSelectedAllVulnerabilities
        ? this.deselectAllVulnerabilities()
        : this.selectAllVulnerabilities();
    },
  },
};
</script>

<template>
  <div class="ci-table js-security-dashboard-table" data-testid="security-report-content">
    <gl-collapse :visible="isSelectingVulnerabilities" data-testid="selection-summary-collapse">
      <selection-summary />
    </gl-collapse>
    <div class="gl-responsive-table-row table-row-header text-2 gl-bg-gray-50 px-2" role="row">
      <div v-if="canAdminVulnerability" class="table-section section-5">
        <gl-form-checkbox
          :checked="hasSelectedAllVulnerabilities"
          class="my-0 ml-1 mr-3"
          @change="handleSelectAll"
        />
      </div>
      <div class="table-section section-15" role="rowheader">
        {{ s__('Reports|Severity') }}
      </div>
      <div class="table-section flex-grow-1" role="rowheader">
        {{ s__('Reports|Vulnerability') }}
      </div>
      <div class="table-section section-15" role="rowheader">
        {{ s__('Reports|Identifier') }}
      </div>
      <div class="table-section section-15" role="rowheader">
        {{ s__('Reports|Tool') }}
      </div>
      <div class="table-section section-20" role="rowheader"></div>
    </div>

    <gl-alert v-if="dashboardListError" variant="danger" :dismissible="false" class="gl-mt-3">
      {{
        s__(
          'SecurityReports|Error fetching the vulnerability list. Please check your network connection and try again.',
        )
      }}
    </gl-alert>

    <template v-if="isLoadingVulnerabilities || isDismissingVulnerabilities">
      <security-dashboard-table-row v-for="n in 10" :key="n" :is-loading="true" />
    </template>

    <template v-else>
      <security-dashboard-table-row
        v-for="vulnerability in vulnerabilities"
        :key="vulnerability.id"
        :vulnerability="vulnerability"
      />

      <slot v-if="showEmptyState" name="empty-state">
        <gl-empty-state
          :title="__(`We've found no vulnerabilities`)"
          :description="
            __(
              `While it's rare to have no vulnerabilities, it can happen. In any event, we ask that you please double check your settings to make sure you've set up your dashboard correctly.`,
            )
          "
        />
      </slot>

      <gl-pagination
        v-if="showCompactPagination"
        data-testid="compact-pagination"
        :value="currentPage"
        :next-page="nextPage"
        :prev-page="previousPage"
        align="center"
        class="gl-mt-3"
        @input="fetchPage"
      />
    </template>
  </div>
</template>

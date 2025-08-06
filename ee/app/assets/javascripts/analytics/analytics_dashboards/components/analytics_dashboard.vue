<script>
import { GlEmptyState, GlSkeletonLoader, GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { createAlert, VARIANT_WARNING, VARIANT_DANGER } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import ValueStreamFeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';
import { BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS } from 'ee/analytics/dashboards/constants';
import UsageOverviewBackgroundAggregationWarning from 'ee/analytics/dashboards/components/usage_overview_background_aggregation_warning.vue';
import UrlSync, {
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
} from '~/vue_shared/components/url_sync.vue';
import { getUniquePanelId } from '../utils';
import {
  AI_IMPACT_DASHBOARD,
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  EVENT_LABEL_VIEWED_DASHBOARD,
  DEFAULT_DASHBOARD_LOADING_ERROR,
  DASHBOARD_REFRESH_MESSAGE,
} from '../constants';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import {
  buildDefaultDashboardFilters,
  filtersToQueryParams,
  isDashboardFilterEnabled,
} from './filters/utils';
import AnalyticsCustomizableDashboard from './analytics_customizable_dashboard.vue';
import AnalyticsDashboardPanel from './analytics_dashboard_panel.vue';

export default {
  name: 'AnalyticsDashboard',
  components: {
    DateRangeFilter: () => import('./filters/date_range_filter.vue'),
    AnonUsersFilter: () => import('./filters/anon_users_filter.vue'),
    ProjectsFilter: () => import('./filters/projects_filter.vue'),
    FilteredSearchFilter: () => import('./filters/filtered_search_filter.vue'),
    AnalyticsCustomizableDashboard,
    AnalyticsDashboardPanel,
    ProductAnalyticsFeedbackBanner,
    ValueStreamFeedbackBanner,
    GlEmptyState,
    GlSkeletonLoader,
    GlAlert,
    UsageOverviewBackgroundAggregationWarning,
    GlLink,
    GlSprintf,
    UrlSync,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    customDashboardsProject: {
      type: Object,
      default: null,
    },
    namespaceFullPath: {
      type: String,
    },
    namespaceId: {
      type: String,
    },
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    dashboardEmptyStateIllustrationPath: {
      type: String,
    },
    breadcrumbState: {
      type: Object,
    },
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  data() {
    return {
      initialDashboard: null,
      showEmptyState: false,
      filters: null,
      backUrl: this.$router.resolve('/').href,
      alert: null,
      hasDashboardLoadError: false,
    };
  },
  computed: {
    currentDashboard() {
      return this.initialDashboard;
    },
    showValueStreamFeedbackBanner() {
      return [BUILT_IN_VALUE_STREAM_DASHBOARD, CUSTOM_VALUE_STREAM_DASHBOARD].includes(
        this.currentDashboard?.slug,
      );
    },
    showProductAnalyticsFeedbackBanner() {
      return (
        !this.currentDashboard?.userDefined &&
        BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS.includes(this.currentDashboard?.slug)
      );
    },
    showFilters() {
      return [
        this.showProjectsFilter,
        this.showAnonUserFilter,
        this.showDateRangeFilter,
        this.showFilteredSearchFilter,
      ].some(Boolean);
    },
    showDateRangeFilter() {
      return isDashboardFilterEnabled(this.dateRangeFilter);
    },
    showProjectsFilter() {
      return this.isGroup && isDashboardFilterEnabled(this.currentDashboard?.filters?.projects);
    },
    dateRangeFilter() {
      return this.currentDashboard?.filters?.dateRange || {};
    },
    dateRangeLimit() {
      return this.dateRangeFilter.numberOfDaysLimit || 0;
    },
    showAnonUserFilter() {
      return isDashboardFilterEnabled(this.currentDashboard?.filters?.excludeAnonymousUsers);
    },
    filteredSearchFilter() {
      return this.currentDashboard?.filters?.filteredSearch;
    },
    showFilteredSearchFilter() {
      return isDashboardFilterEnabled(this.filteredSearchFilter);
    },
    invalidDashboardErrors() {
      return this.currentDashboard?.errors ?? [];
    },
    hasDashboardError() {
      return this.hasDashboardLoadError || this.invalidDashboardErrors.length > 0;
    },
    dashboardHasUsageOverviewPanel() {
      return this.currentDashboard?.panels
        .map(({ visualization: { slug } }) => slug)
        .includes('usage_overview');
    },
    showEnableAggregationWarning() {
      return this.dashboardHasUsageOverviewPanel && !this.overviewCountsAggregationEnabled;
    },
    hasCustomDescriptionLink() {
      return this.isValueStreamsDashboard || this.isAiImpactDashboard;
    },
    isValueStreamsDashboard() {
      return this.currentDashboard.slug === BUILT_IN_VALUE_STREAM_DASHBOARD;
    },
    isAiImpactDashboard() {
      return this.currentDashboard.slug === AI_IMPACT_DASHBOARD;
    },
    queryParams() {
      return filtersToQueryParams(this.filters);
    },
    dateRangeOptions() {
      return this.currentDashboard.filters?.dateRange?.options;
    },
    filteredSearchOptions() {
      return this.currentDashboard.filters?.filteredSearch?.options;
    },
  },
  watch: {
    initialDashboard({ title: label, userDefined } = {}) {
      this.trackEvent(EVENT_LABEL_VIEWED_DASHBOARD, {
        label,
      });

      this.filters = buildDefaultDashboardFilters(
        window.location.search,
        this.currentDashboard.filters,
      );

      if (userDefined) {
        this.trackEvent(EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD, {
          label,
        });
      } else {
        this.trackEvent(EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD, {
          label,
        });
      }
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();

    // Clear the breadcrumb name when we leave this component so it doesn't
    // flash the wrong name when a user views a different dashboard
    this.breadcrumbState.updateName('');
  },
  apollo: {
    initialDashboard: {
      query: getCustomizableDashboardQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          slug: this.$route?.params.slug,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;
        const [dashboard] = namespaceData?.customizableDashboards?.nodes || [];

        if (!dashboard) {
          this.showEmptyState = true;
          return null;
        }

        return {
          ...dashboard,
          panels: this.getDashboardPanels(dashboard),
        };
      },
      result() {
        this.breadcrumbState.updateName(this.initialDashboard?.title || '');

        this.validateFilters(this.initialDashboard?.filters);
      },
      error(error) {
        const message = [
          error.message || DEFAULT_DASHBOARD_LOADING_ERROR,
          DASHBOARD_REFRESH_MESSAGE,
        ].join('. ');

        this.showError({
          error,
          capture: true,
          title: s__('Analytics|Failed to load dashboard'),
          message,
          messageLinks: {
            link: this.$options.troubleshootingUrl,
          },
        });
        this.hasDashboardLoadError = true;
      },
    },
  },
  methods: {
    getDashboardPanels(dashboard) {
      const panels = dashboard.panels?.nodes || [];

      return panels.map(({ id, ...panel }) => ({
        ...panel,
        id: getUniquePanelId(),
      }));
    },
    showError({ error, capture, message, messageLinks, title = '', variant = VARIANT_DANGER }) {
      this.alert = createAlert({
        variant,
        title,
        message,
        messageLinks,
        error,
        captureError: capture,
      });
    },
    validateFilters(filters = {}) {
      if (filters?.dateRange?.enabled && filters?.dateRange.defaultOption) {
        const {
          dateRange: { defaultOption, options = [] },
        } = filters;
        if (!options.includes(defaultOption)) {
          this.showError({
            title: this.$options.i18n.dateRangeFilterValidationTitle,
            variant: VARIANT_WARNING,
            message: sprintf(this.$options.i18n.dateRangeFilterValidationMessage, {
              defaultOption,
            }),
          });
        }
      }
    },
    panelTestId({ visualization: { slug = '' } }) {
      return `panel-${slug.replaceAll('_', '-')}`;
    },
    setDateRangeFilter({ dateRangeOption, startDate, endDate }) {
      this.filters = {
        ...this.filters,
        dateRangeOption,
        startDate,
        endDate,
      };
    },
    setAnonymousUsersFilter(filterAnonUsers) {
      this.filters = {
        ...this.filters,
        filterAnonUsers,
      };

      if (filterAnonUsers) {
        this.trackEvent(EVENT_LABEL_EXCLUDE_ANONYMISED_USERS);
      }
    },
    setProjectsFilter(project) {
      this.filters = {
        ...this.filters,
        projectFullPath: project?.fullPath || null,
      };
    },
    setFilteredSearchFilter(searchFilters) {
      this.filters = {
        ...this.filters,
        searchFilters,
      };
    },
  },
  troubleshootingUrl: helpPagePath('user/analytics/analytics_dashboards', {
    anchor: '#troubleshooting',
  }),
  i18n: {
    aiImpactDescriptionLink: s__(
      'Analytics|Learn more about %{docsLinkStart}AI impact analytics%{docsLinkEnd} and %{subscriptionLinkStart}GitLab Duo seats%{subscriptionLinkEnd}.',
    ),
    dateRangeFilterValidationTitle: __('Date range filter validation'),
    dateRangeFilterValidationMessage: s__(
      "Analytics|Default date range '%{defaultOption}' is not included in the list of dateRange options",
    ),
  },
  VSD_DOCUMENTATION_LINK: helpPagePath('user/analytics/value_streams_dashboard'),
  AI_IMPACT_DOCUMENTATION_LINK: helpPagePath('user/analytics/ai_impact_analytics'),
  DUO_PRO_SUBSCRIPTION_ADD_ON_LINK: helpPagePath('subscriptions/subscription-add-ons'),
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
};
</script>

<template>
  <div>
    <template v-if="currentDashboard">
      <gl-alert
        v-if="invalidDashboardErrors.length > 0"
        data-testid="analytics-dashboard-invalid-config-alert"
        class="gl-mt-4"
        :title="s__('Analytics|Invalid dashboard configuration')"
        :primary-button-text="__('Learn more')"
        :primary-button-link="$options.troubleshootingUrl"
        :dismissible="false"
        variant="danger"
      >
        <ul class="gl-m-0">
          <li v-for="errorMessage in invalidDashboardErrors" :key="errorMessage">
            {{ errorMessage }}
          </li>
        </ul>
      </gl-alert>
      <value-stream-feedback-banner v-if="showValueStreamFeedbackBanner" />
      <product-analytics-feedback-banner v-if="showProductAnalyticsFeedbackBanner" />

      <analytics-customizable-dashboard ref="dashboard" :dashboard="currentDashboard">
        <!-- TODO: Remove this link in https://gitlab.com/gitlab-org/gitlab/-/issues/465569 -->
        <template v-if="hasCustomDescriptionLink" #after-description>
          <span data-testid="after-description-link">
            <gl-sprintf v-if="isAiImpactDashboard" :message="$options.i18n.aiImpactDescriptionLink">
              <template #docsLink="{ content }">
                <gl-link :href="$options.AI_IMPACT_DOCUMENTATION_LINK">{{ content }}</gl-link>
              </template>
              <template #subscriptionLink="{ content }">
                <gl-link :href="$options.DUO_PRO_SUBSCRIPTION_ADD_ON_LINK">{{ content }}</gl-link>
              </template>
            </gl-sprintf>

            <gl-sprintf
              v-else-if="isValueStreamsDashboard"
              :message="__('%{linkStart} Learn more%{linkEnd}.')"
            >
              <template #link="{ content }">
                <gl-link :href="$options.VSD_DOCUMENTATION_LINK">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>

        <template #alert>
          <div v-if="showEnableAggregationWarning" class="gl-mx-3">
            <usage-overview-background-aggregation-warning />
          </div>
        </template>

        <template v-if="showFilters" #filters>
          <filtered-search-filter
            v-if="showFilteredSearchFilter"
            class="gl-basis-full"
            :initial-filter-value="filters.searchFilters"
            :options="filteredSearchOptions"
            @change="setFilteredSearchFilter"
          />
          <projects-filter
            v-if="showProjectsFilter"
            :group-namespace="namespaceFullPath"
            @projectSelected="setProjectsFilter"
          />
          <date-range-filter
            v-if="showDateRangeFilter"
            :default-option="filters.dateRangeOption"
            :start-date="filters.startDate"
            :end-date="filters.endDate"
            :date-range-limit="dateRangeLimit"
            :options="dateRangeOptions"
            @change="setDateRangeFilter"
          />
          <anon-users-filter
            v-if="showAnonUserFilter"
            :value="filters.filterAnonUsers"
            @change="setAnonymousUsersFilter"
          />
          <url-sync
            :query="queryParams"
            :url-params-update-strategy="$options.URL_SET_PARAMS_STRATEGY"
            :history-update-method="$options.HISTORY_REPLACE_UPDATE_METHOD"
          />
        </template>

        <template #panel="{ panel }">
          <analytics-dashboard-panel
            :title="panel.title"
            :visualization="panel.visualization"
            :query-overrides="panel.queryOverrides || undefined"
            :filters="filters"
            :data-testid="panelTestId(panel)"
          />
        </template>
      </analytics-customizable-dashboard>
    </template>
    <gl-empty-state
      v-else-if="showEmptyState"
      :svg-path="dashboardEmptyStateIllustrationPath"
      :title="s__('Analytics|Dashboard not found')"
      :description="s__('Analytics|No dashboard matches the specified URL path.')"
      :primary-button-text="s__('Analytics|View available dashboards')"
      :primary-button-link="backUrl"
    />
    <div v-else-if="!hasDashboardError" class="gl-mt-7">
      <gl-skeleton-loader />
    </div>
  </div>
</template>

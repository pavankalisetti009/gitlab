<script>
import { GlLink, GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import getAllCustomizableDashboardsQuery from '../graphql/queries/get_all_customizable_dashboards.query.graphql';
import DashboardListItem from './list/dashboard_list_item.vue';

const productAnalyticsOnboardingType = 'productAnalytics';
const ONBOARDING_FEATURE_COMPONENTS = {
  [productAnalyticsOnboardingType]: () =>
    import('ee/product_analytics/onboarding/components/onboarding_list_item.vue'),
};

export default {
  name: 'DashboardsList',
  components: {
    DashboardListItem,
    GlAlert,
    GlButton,
    GlLink,
    GlSprintf,
    PageHeading,
    ResourceListsLoadingStateList,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    namespaceFullPath: {
      type: String,
    },
    features: {
      type: Array,
      default: () => [],
    },
    analyticsSettingsPath: {
      type: String,
    },
  },
  data() {
    return {
      requiresOnboarding: Object.keys(ONBOARDING_FEATURE_COMPONENTS),
      userDashboards: [],
      alert: null,
    };
  },
  computed: {
    dashboards() {
      return this.userDashboards;
    },
    isLoading() {
      return this.$apollo.queries.userDashboards.loading;
    },
    activeOnboardingComponents() {
      return Object.fromEntries(
        Object.entries(ONBOARDING_FEATURE_COMPONENTS)
          .filter(this.featureEnabled)
          .filter(this.featureRequiresOnboarding),
      );
    },
  },
  mounted() {
    this.trackEvent('user_viewed_dashboard_list');
  },
  apollo: {
    userDashboards: {
      query: getAllCustomizableDashboardsQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;

        return namespaceData?.customizableDashboards?.nodes;
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();
  },
  methods: {
    featureEnabled([feature]) {
      return this.features.includes(feature);
    },
    featureRequiresOnboarding([feature]) {
      return this.requiresOnboarding.includes(feature);
    },
    onboardingComplete(feature) {
      this.requiresOnboarding = this.requiresOnboarding.filter((f) => f !== feature);

      this.$apollo.queries.userDashboards.refetch();
    },
    onError(error, captureError = true, message = '') {
      this.alert = createAlert({
        message: message || error.message,
        captureError,
        error,
      });
    },
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards'),
};
</script>

<template>
  <div>
    <page-heading :heading="s__('Analytics|Analytics dashboards')">
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'Analytics|%{linkStart}Learn more%{linkEnd} about managing and interacting with analytics dashboards.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>
    <ul data-testid="dashboards-list" class="content-list gl-border-t gl-border-subtle">
      <component
        :is="setupComponent"
        v-for="(setupComponent, feature) in activeOnboardingComponents"
        :key="feature"
        @complete="onboardingComplete(feature)"
        @error="onError"
      />
      <resource-lists-loading-state-list v-if="isLoading" />
      <template v-else>
        <dashboard-list-item
          v-for="dashboard in dashboards"
          :key="dashboard.slug"
          :dashboard="dashboard"
          data-event-tracking="user_visited_dashboard"
        />
      </template>
    </ul>
  </div>
</template>

<script>
import { unescape } from 'lodash';
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { sanitize } from '~/lib/dompurify';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';

export default {
  name: 'MigrationAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    UserCalloutDismisser,
  },
  inject: ['analyticsDashboardsPath', 'mrAnalyticsDashboardPath'],
  i18n: {
    title: s__('MergeRequestAnalytics|Merge request analytics is moving'),
    message: unescape(
      sanitize(
        s__(
          'MergeRequestAnalytics|This page will move to %{dashboardsListLinkStart}Analytics dashboards%{dashboardsListLinkEnd} &gt; %{mrDashboardLinkStart}Merge request analytics%{mrDashboardLinkEnd} in GitLab 18.6.',
        ),
        { ALLOWED_TAGS: [] },
      ),
    ),
  },
};
</script>
<template>
  <user-callout-dismisser feature-name="mr_analytics_dashboard_migration">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-alert
        v-if="shouldShowCallout"
        :title="$options.i18n.title"
        class="gl-mb-4"
        @dismiss="dismiss"
      >
        <gl-sprintf :message="$options.i18n.message">
          <template #dashboardsListLink="{ content }">
            <gl-link
              data-testid="dashboardsListLink"
              variant="unstyled"
              :href="analyticsDashboardsPath"
              >{{ content }}</gl-link
            >
          </template>
          <template #mrDashboardLink="{ content }">
            <gl-link
              data-testid="mrDashboardLink"
              variant="unstyled"
              :href="mrAnalyticsDashboardPath"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </gl-alert>
    </template>
  </user-callout-dismisser>
</template>

<script>
import { GlTabs, GlTab, GlLink } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import MigrationAlert from 'ee/analytics/dora/components/migration_alert.vue';
import { mergeUrlParams, updateHistory, getParameterValues } from '~/lib/utils/url_utility';
import API from '~/api';
import ReleaseStatsCard from './release_stats_card.vue';

export default {
  name: 'GroupCiCdAnalyticsApp',
  components: {
    ReleaseStatsCard,
    GlTabs,
    GlTab,
    GlLink,
    MigrationAlert,
  },
  releaseStatisticsTabEvent: 'g_analytics_ci_cd_release_statistics',
  mixins: [glFeatureFlagsMixin()],
  inject: {
    groupPath: {
      type: String,
      default: '',
    },
    pipelineGroupUsageQuotaPath: {
      type: String,
      default: '',
    },
    canViewGroupUsageQuotaBoolean: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedTabIndex: 0,
    };
  },
  computed: {
    tabs() {
      const tabsToShow = ['release-statistics'];

      tabsToShow.push('shared-runner-usage');

      return tabsToShow;
    },
    releaseStatsCardClasses() {
      return ['gl-mt-5'];
    },
  },
  created() {
    this.selectTab();
    window.addEventListener('popstate', this.selectTab);
  },
  methods: {
    selectTab() {
      const [tabQueryParam] = getParameterValues('tab');
      const tabIndex = this.tabs.indexOf(tabQueryParam);
      this.selectedTabIndex = tabIndex >= 0 ? tabIndex : 0;
    },
    onTabChange(newIndex) {
      if (newIndex !== this.selectedTabIndex) {
        this.selectedTabIndex = newIndex;
        const path = mergeUrlParams({ tab: this.tabs[newIndex] }, window.location.pathname);
        updateHistory({ url: path, title: window.title });
      }
    },
    trackTabClick(tab) {
      API.trackRedisHllUserEvent(tab);
    },
  },
};
</script>
<template>
  <div>
    <migration-alert :namespace-path="groupPath" />

    <gl-tabs v-if="tabs.length > 1" :value="selectedTabIndex" @input="onTabChange">
      <gl-tab
        :title="s__('CICDAnalytics|Release statistics')"
        data-testid="release-statistics-tab"
        @click="trackTabClick($options.releaseStatisticsTabEvent)"
      >
        <release-stats-card :class="releaseStatsCardClasses" />
      </gl-tab>
      <template v-if="canViewGroupUsageQuotaBoolean" #tabs-end>
        <gl-link :href="pipelineGroupUsageQuotaPath" class="gl-ml-auto gl-self-center">{{
          __('View group pipeline usage quota')
        }}</gl-link>
      </template>
    </gl-tabs>
    <release-stats-card v-else :class="releaseStatsCardClasses" />
  </div>
</template>

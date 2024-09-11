<script>
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import { s__ } from '~/locale';

export default {
  name: 'PagesDeploymentsStats',
  components: { StatisticsCard },
  inject: ['fullPath', 'deploymentsLimit', 'deploymentsCount'],
  static: {
    helpLink: `${DOCS_URL_IN_EE_DIR}/user/project/pages/#limits`,
  },
  i18n: {
    description: s__('PagesUsageQuota|Parallel deployments'),
    helpText: s__('PagesUsageQuota|Learn about limits for Pages deployments'),
  },
  computed: {
    percentage() {
      return (this.deploymentsCount / this.deploymentsLimit) * 100;
    },
  },
};
</script>

<template>
  <statistics-card
    :usage-value="`${deploymentsCount}`"
    :total-value="deploymentsLimit"
    :description="$options.i18n.description"
    :help-link="$options.static.helpLink"
    :help-label="$options.i18n.helpText"
    :help-tooltip="$options.i18n.helpText"
    :percentage="percentage"
  />
</template>

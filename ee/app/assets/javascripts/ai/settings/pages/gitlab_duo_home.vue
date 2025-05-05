<script>
import { __, s__ } from '~/locale';
import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE } from 'ee/usage_quotas/code_suggestions/constants';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import DuoSeatUtilizationInfoCard from '../components/duo_seat_utilization_info_card.vue';
import DuoConfigurationSettingsInfoCard from '../components/duo_configuration_settings_info_card.vue';
import DuoSelfHostedInfoCard from '../components/duo_self_hosted_info_card.vue';

export default {
  name: 'GitlabDuoHome',
  components: {
    CodeSuggestionsUsage,
    HealthCheckList,
    DuoConfigurationSettingsInfoCard,
    DuoCoreUpgradeCard,
    DuoSeatUtilizationInfoCard,
    DuoSelfHostedInfoCard,
  },
  inject: {
    canManageSelfHostedModels: { default: false },
    isSaaS: {},
  },
  i18n: {
    gitlabDuoHomeTitle: __('GitLab Duo'),
    gitlabDuoHomeSubtitle: s__(
      'AiPowered|Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
    ),
  },
  methods: {
    shouldShowDuoCoreUpgradeCard(duoTier) {
      return duoTier === DUO_CORE;
    },
    shouldShowSeatUtilizationInfoCard(duoTier) {
      return duoTier === DUO_PRO || duoTier === DUO_ENTERPRISE;
    },
  },
};
</script>

<template>
  <code-suggestions-usage
    :title="$options.i18n.gitlabDuoHomeTitle"
    :subtitle="$options.i18n.gitlabDuoHomeSubtitle"
    :force-hide-title="false"
    v-bind="$attrs"
  >
    <template #health-check>
      <health-check-list v-if="!isSaaS" />
    </template>
    <template #duo-card="{ totalValue, usageValue, duoTier }">
      <section class="gl-grid gl-gap-5 gl-pb-5 md:gl-grid-cols-2">
        <duo-core-upgrade-card v-if="shouldShowDuoCoreUpgradeCard(duoTier)" />
        <duo-seat-utilization-info-card
          v-if="shouldShowSeatUtilizationInfoCard(duoTier)"
          :total-value="totalValue"
          :usage-value="usageValue"
          :duo-tier="duoTier"
        />
        <duo-configuration-settings-info-card :duo-tier="duoTier" />
      </section>
      <duo-self-hosted-info-card v-if="!isSaaS && canManageSelfHostedModels" />
    </template>
  </code-suggestions-usage>
</template>

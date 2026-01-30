<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { minBy } from 'lodash';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import UpgradePlanHeader from 'ee/vue_shared/subscription/components/upgrade_plan_header.vue';
import CurrentPlanHeader from 'ee/vue_shared/subscription/components/current_plan_header.vue';
import { instanceHasFutureLicenseBanner } from '../constants';
import SubscriptionActivationCard from './subscription_activation_card.vue';
import SubscriptionDetailsHistory from './subscription_details_history.vue';

export default {
  name: 'NoActiveSubscription',
  components: {
    CurrentPlanHeader,
    UpgradePlanHeader,
    GlAlert,
    GlSprintf,
    SubscriptionActivationCard,
    SubscriptionDetailsHistory,
  },
  inject: ['freeTrialPath', 'groupsCount', 'projectsCount', 'usersCount'],
  i18n: {
    instanceHasFutureLicenseBanner,
  },
  props: {
    subscriptionList: {
      type: Array,
      required: true,
    },
  },
  computed: {
    hasItems() {
      return Boolean(this.subscriptionList.length);
    },
    nextFutureDatedLicenseDate() {
      const futureItems = this.subscriptionList.filter((license) =>
        isInFuture(new Date(license.startsAt)),
      );
      const nextFutureDatedItem = minBy(futureItems, (license) => new Date(license.startsAt));
      return nextFutureDatedItem?.startsAt;
    },
    hasFutureDatedLicense() {
      return Boolean(this.nextFutureDatedLicenseDate);
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-6 gl-flex gl-flex-col md:gl-flex-row">
      <current-plan-header
        :seats-in-use="usersCount"
        :total-projects="projectsCount"
        :total-groups="groupsCount"
        :trial-active="false"
        :is-saas="false"
      />

      <upgrade-plan-header
        :trial-active="false"
        :trial-expired="false"
        :start-trial-path="freeTrialPath"
        :can-access-duo-chat="false"
        :is-saas="false"
      />
    </div>

    <subscription-activation-card v-on="$listeners" />

    <gl-alert
      v-if="hasFutureDatedLicense"
      :title="$options.i18n.instanceHasFutureLicenseBanner.title"
      :dismissible="false"
      class="gl-mt-5"
      variant="info"
      data-testid="subscription-future-licenses-alert"
    >
      <gl-sprintf :message="$options.i18n.instanceHasFutureLicenseBanner.message">
        <template #date>{{ nextFutureDatedLicenseDate }}</template>
      </gl-sprintf>
    </gl-alert>

    <div v-if="hasItems && hasFutureDatedLicense" class="gl-col-12 gl-mt-5">
      <subscription-details-history :subscription-list="subscriptionList" />
    </div>

    <div v-if="hasItems && !hasFutureDatedLicense" class="gl-col-12 gl-mt-5">
      <subscription-details-history :subscription-list="subscriptionList" />
    </div>
  </div>
</template>

<script>
import { GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import {
  seatsAvailableText,
  seatsInSubscriptionText,
  seatsInSubscriptionTextForFreePlan,
  seatsInUseLink,
  seatsTooltipText,
  seatsTooltipTrialText,
  unlimited,
} from 'ee/usage_quotas/seats/constants';
import { sprintf } from '~/locale';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import { updateSubscriptionPlanApolloCache } from 'ee/usage_quotas/seats/graphql/utils';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import SubscriptionUpgradeInfoCard from './subscription_upgrade_info_card.vue';
import SubscriptionUserList from './subscription_user_list.vue';

export default {
  name: 'SubscriptionSeats',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    PublicNamespacePlanInfoCard,
    StatisticsCard,
    StatisticsSeatsCard,
    SubscriptionUpgradeInfoCard,
    SubscriptionUserList,
    GlSkeletonLoader,
  },
  inject: ['isPublicNamespace'],
  computed: {
    ...mapState([
      'namespaceId',
      'hasError',
      'total',
      'seatsInSubscription',
      'seatsInUse',
      'maxSeatsUsed',
      'seatsOwed',
      'addSeatsHref',
      'hasNoSubscription',
      'maxFreeNamespaceSeats',
      'explorePlansPath',
      'hasLimitedFreePlan',
      'hasReachedFreePlanLimit',
      'activeTrial',
    ]),
    ...mapGetters(['hasFreePlan', 'isLoading']),
    isPublicFreeNamespace() {
      return this.hasFreePlan && this.isPublicNamespace;
    },
    seatsInUsePercentage() {
      if (this.totalSeatsAvailable == null || this.activeTrial) {
        return 0;
      }

      return Math.round((this.totalSeatsInUse * 100) / this.totalSeatsAvailable);
    },
    totalSeatsAvailable() {
      if (this.hasNoSubscription) {
        return this.hasLimitedFreePlan ? this.maxFreeNamespaceSeats : null;
      }
      return this.seatsInSubscription;
    },
    totalSeatsInUse() {
      if (this.hasLimitedFreePlan) {
        return this.seatsInUse;
      }
      return this.total;
    },
    seatsInUseText() {
      if (this.hasFreePlan) {
        return this.$options.i18n.seatsInSubscriptionTextForFreePlan;
      }

      return this.hasLimitedFreePlan
        ? this.$options.i18n.seatsAvailableText
        : this.$options.i18n.seatsInSubscriptionText;
    },
    seatsInUseTooltipText() {
      if (!this.hasLimitedFreePlan) return null;
      if (this.activeTrial) return this.$options.i18n.seatsTooltipTrialText;

      return sprintf(this.$options.i18n.seatsTooltipText, { number: this.maxFreeNamespaceSeats });
    },
    displayedTotalSeats() {
      if (this.activeTrial) return this.$options.i18n.unlimited;

      return this.totalSeatsAvailable
        ? String(this.totalSeatsAvailable)
        : this.$options.i18n.unlimited;
    },
    showUpgradeInfoCard() {
      if (!this.hasNoSubscription) {
        return false;
      }
      return this.hasLimitedFreePlan;
    },
    isLoaderShown() {
      return this.isLoading || this.hasError;
    },
  },
  created() {
    /* This will be removed with https://gitlab.com/groups/gitlab-org/-/epics/11942 */
    this.$store.subscribeAction({
      after: (action, state) => {
        if (action.type === 'receiveGitlabSubscriptionSuccess') {
          updateSubscriptionPlanApolloCache(this.$apolloProvider, {
            planCode: state.planCode,
            planName: state.planName,
            subscriptionId: state.namespaceId,
            subscriptionEndDate: state.subscriptionEndDate,
            subscriptionStartDate: state.subscriptionStartDate,
          });
        }
      },
    });
    this.$store.dispatch('fetchInitialData');
  },
  helpLinks: {
    seatsInUseLink,
  },
  i18n: {
    seatsInSubscriptionTextForFreePlan,
    seatsAvailableText,
    seatsInSubscriptionText,
    seatsTooltipTrialText,
    seatsTooltipText,
    unlimited,
  },
};
</script>

<template>
  <section>
    <div class="gl-bg-gray-10 gl-p-5">
      <div
        v-if="isLoaderShown"
        class="gl-grid gl-gap-5 md:gl-grid-cols-2"
        data-testid="skeleton-loader-cards"
      >
        <div class="gl-border gl-rounded-base gl-bg-white gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>

        <div class="gl-border gl-rounded-base gl-bg-white gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>
      </div>
      <div v-else class="gl-grid gl-gap-5 md:gl-grid-cols-2">
        <statistics-card
          :help-link="$options.helpLinks.seatsInUseLink"
          :help-tooltip="seatsInUseTooltipText"
          :description="seatsInUseText"
          :percentage="seatsInUsePercentage"
          :usage-value="String(totalSeatsInUse)"
          :total-value="displayedTotalSeats"
          data-testid="seats-in-use"
        />
        <subscription-upgrade-info-card
          v-if="showUpgradeInfoCard"
          :max-namespace-seats="maxFreeNamespaceSeats"
          :explore-plans-path="explorePlansPath"
          :active-trial="activeTrial"
        />
        <public-namespace-plan-info-card v-else-if="isPublicFreeNamespace" />
        <!-- StatisticsSeatsCard will eventually be replaced. See https://gitlab.com/gitlab-org/gitlab/-/issues/429828 -->
        <statistics-seats-card
          v-else
          :seats-used="maxSeatsUsed"
          :seats-owed="seatsOwed"
          :purchase-button-link="addSeatsHref"
          :namespace-id="namespaceId"
        />
      </div>
    </div>

    <subscription-user-list :has-free-plan="hasFreePlan" />
  </section>
</template>

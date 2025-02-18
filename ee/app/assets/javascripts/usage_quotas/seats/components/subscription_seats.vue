<script>
import { GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { PLAN_CODE_FREE } from 'ee/usage_quotas/seats/constants';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import * as types from '../store/mutation_types';
import SubscriptionUpgradeInfoCard from './subscription_upgrade_info_card.vue';
import SubscriptionUserList from './subscription_user_list.vue';

export default {
  name: 'SubscriptionSeats',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    PublicNamespacePlanInfoCard,
    SubscriptionSeatsStatisticsCard,
    StatisticsSeatsCard,
    SubscriptionUpgradeInfoCard,
    SubscriptionUserList,
    GlSkeletonLoader,
  },
  apollo: {
    billableMembersCount: {
      query: getBillableMembersCountQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.group.billableMembersCount;
      },
      error() {
        this.receiveBillableMembersListError();
      },
    },
    plan: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update(data) {
        this.$store.commit(types.RECEIVE_GITLAB_SUBSCRIPTION_SUCCESS, data?.subscription);
        return data?.subscription?.plan || {};
      },
      error: (error) => {
        createAlert({
          message: s__('Billing|An error occurred while loading GitLab subscription details.'),
        });

        Sentry.captureException(error);
      },
    },
  },
  inject: [
    'fullPath',
    'isPublicNamespace',
    'explorePlansPath',
    'addSeatsHref',
    'hasNoSubscription',
    'namespaceId',
  ],
  data() {
    return {
      plan: {},
      billableMembersCount: 0,
    };
  },
  computed: {
    ...mapState([
      'hasError',
      'maxSeatsUsed',
      'seatsOwed',
      'maxFreeNamespaceSeats',
      'hasLimitedFreePlan',
      'activeTrial',
    ]),
    ...mapGetters(['isLoading']),
    isPublicFreeNamespace() {
      return this.hasFreePlan && this.isPublicNamespace;
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
    hasFreePlan() {
      return this.plan.code === PLAN_CODE_FREE;
    },
  },
  created() {
    this.$store.dispatch('fetchInitialData');
  },
  methods: {
    ...mapActions(['receiveBillableMembersListError']),
  },
};
</script>

<template>
  <section>
    <div class="gl-bg-subtle gl-p-5">
      <div
        v-if="isLoaderShown"
        class="gl-grid gl-gap-5 md:gl-grid-cols-2"
        data-testid="skeleton-loader-cards"
      >
        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>

        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>
      </div>
      <div v-else class="gl-grid gl-gap-5 md:gl-grid-cols-2">
        <subscription-seats-statistics-card
          :billable-members-count="billableMembersCount"
          :has-free-plan="hasFreePlan"
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
          :has-free-plan="hasFreePlan"
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

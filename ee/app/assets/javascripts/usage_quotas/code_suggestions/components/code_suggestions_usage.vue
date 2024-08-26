<script>
import { GlSkeletonLoader, GlBadge } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import getAddOnPurchaseQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchase.query.graphql';
import getAddOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import {
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  DUO_ENTERPRISE,
  DUO_PRO,
  DUO_ENTERPRISE_TITLE,
  CODE_SUGGESTIONS_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import CodeSuggestionsInfoCard from './code_suggestions_info_card.vue';
import CodeSuggestionsIntro from './code_suggestions_intro.vue';
import CodeSuggestionsStatisticsCard from './code_suggestions_usage_statistics_card.vue';
import HealthCheckList from './health_check_list.vue';

export default {
  name: 'CodeSuggestionsUsage',
  components: {
    ErrorAlert,
    SaasAddOnEligibleUserList,
    SelfManagedAddOnEligibleUserList,
    CodeSuggestionsInfoCard,
    CodeSuggestionsIntro,
    CodeSuggestionsStatisticsCard,
    GlSkeletonLoader,
    HealthCheckList,
    GlBadge,
  },
  inject: { isSaaS: {}, isStandalonePage: { default: false }, groupId: { default: null } },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  i18n: {
    codeSuggestionTitle: __('GitLab Duo'),
  },
  data() {
    return {
      addOnPurchaseData: undefined,
      addOnPurchaseFetchError: undefined,
      deprecatedAddOnPurchaseData: undefined,
      useDeprecatedAddOnPurchaseQuery: false,
    };
  },
  computed: {
    addOnPurchase() {
      return this.addOnPurchaseData ?? this.deprecatedAddOnPurchaseData;
    },
    queryVariables() {
      return {
        namespaceId: this.groupGraphQLId,
      };
    },
    deprecatedQueryVariables() {
      return {
        addOnType: ADD_ON_CODE_SUGGESTIONS,
        namespaceId: this.groupGraphQLId,
      };
    },
    groupGraphQLId() {
      return this.groupId ? convertToGraphQLId(TYPENAME_GROUP, this.groupId) : null;
    },
    totalValue() {
      return this.addOnPurchase?.purchasedQuantity ?? 0;
    },
    usageValue() {
      return this.addOnPurchase?.assignedQuantity ?? 0;
    },
    hasCodeSuggestions() {
      return this.totalValue !== null && this.totalValue > 0;
    },
    isLoading() {
      return (
        this.$apollo.queries.addOnPurchaseData.loading ||
        this.$apollo.queries.deprecatedAddOnPurchaseData.loading
      );
    },
    duoTier() {
      return this.addOnPurchase?.name === ADD_ON_DUO_ENTERPRISE ? DUO_ENTERPRISE : DUO_PRO;
    },
    showTitleAndSubtitle() {
      if (this.isSaaS && !this.isStandalonePage) {
        return false;
      }

      return !this.isLoading && (this.hasCodeSuggestions || this.addOnPurchaseFetchError);
    },
    saasSubtitle() {
      return sprintf(s__('CodeSuggestions|Manage seat assignments for %{addOnName}.'), {
        addOnName: this.codeSuggestionsFriendlyName,
      });
    },
    selfManagedSubtitle() {
      return sprintf(
        s__(
          'CodeSuggestions|Manage seat assignments for %{addOnName} or run a health check to identify problems.',
        ),
        {
          addOnName: this.codeSuggestionsFriendlyName,
        },
      );
    },
    codeSuggestionsFriendlyName() {
      return this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE;
    },
    statusCheckEnabled() {
      return !this.isSaaS;
    },
  },
  apollo: {
    addOnPurchaseData: {
      query: getAddOnPurchasesQuery,
      variables() {
        return this.queryVariables;
      },
      update({ addOnPurchases }) {
        return (
          // Prioritize Duo Enterprise add-on over Duo Pro if both are available to the namespace.
          // For example, a namespace can have a Duo Pro add-on but also a Duo Enterprise trial add-on.
          addOnPurchases?.find((addOnPurchase) => addOnPurchase.name === ADD_ON_DUO_ENTERPRISE) ||
          addOnPurchases?.find((addOnPurchase) => addOnPurchase.name === ADD_ON_CODE_SUGGESTIONS)
        );
      },
      error() {
        this.useDeprecatedAddOnPurchaseQuery = true;
      },
    },
    // This is a fallback request in case getAddOnPurchases query is not yet available.
    // Context: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/160561#note_2025278675
    // This request can be removed after the 17.4 release, tracked here:
    // https://gitlab.com/gitlab-org/gitlab/-/issues/476858
    deprecatedAddOnPurchaseData: {
      query: getAddOnPurchaseQuery,
      skip() {
        return !this.useDeprecatedAddOnPurchaseQuery;
      },
      variables() {
        return this.deprecatedQueryVariables;
      },
      update({ addOnPurchase }) {
        return addOnPurchase;
      },
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.handleAddOnPurchaseFetchError(errorWithCause);
        this.reportError(error);
      },
    },
  },
  methods: {
    handleAddOnPurchaseFetchError(error) {
      this.addOnPurchaseFetchError = error;
    },
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
  },
};
</script>

<template>
  <section>
    <section v-if="isLoading">
      <div class="gl-mt-5">
        <div class="gl-border gl-rounded-base gl-bg-white gl-p-5">
          <gl-skeleton-loader :height="10">
            <circle cx="4" cy="6" r="2" />
            <rect width="100" height="4" x="8" y="4" rx="2" />
            <rect width="10%" height="100%" x="90%" y="0" rx="1" />
          </gl-skeleton-loader>
        </div>
      </div>

      <div class="gl-mt-5 gl-grid gl-gap-5 md:gl-grid-cols-2">
        <div class="gl-border gl-rounded-base gl-bg-white gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>

        <div class="gl-border gl-rounded-base gl-bg-white gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="240" height="10" x="5" y="0" rx="4" />
            <rect width="340" height="10" x="5" y="14" rx="4" />
            <rect width="220" height="8" x="5" y="40" rx="4" />
            <rect width="220" height="8" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>
      </div>
    </section>
    <template v-else>
      <template v-if="showTitleAndSubtitle">
        <section>
          <header class="gl-flex gl-items-center">
            <h1 data-testid="code-suggestions-title" class="page-title gl-text-size-h-display">
              {{ $options.i18n.codeSuggestionTitle }}
            </h1>

            <gl-badge variant="tier" icon="license" class="gl-capitalize gl-ml-3 gl-py-2 gl-px-3">{{
              duoTier
            }}</gl-badge>
          </header>

          <p v-if="isSaaS" data-testid="code-suggestions-subtitle">
            {{ saasSubtitle }}
          </p>
          <p v-else data-testid="code-suggestions-subtitle">
            {{ selfManagedSubtitle }}
          </p>
        </section>

        <health-check-list v-if="statusCheckEnabled" />
      </template>

      <section v-if="hasCodeSuggestions">
        <section class="gl-grid gl-gap-5 md:gl-grid-cols-2">
          <code-suggestions-statistics-card
            :total-value="totalValue"
            :usage-value="usageValue"
            :duo-tier="duoTier"
          />
          <code-suggestions-info-card
            :group-id="groupId"
            :duo-tier="duoTier"
            @error="handleAddOnPurchaseFetchError"
          />
        </section>
        <saas-add-on-eligible-user-list
          v-if="isSaaS"
          :add-on-purchase-id="addOnPurchase.id"
          :duo-tier="duoTier"
        />
        <self-managed-add-on-eligible-user-list
          v-else
          :add-on-purchase-id="addOnPurchase.id"
          :duo-tier="duoTier"
        />
      </section>
      <error-alert
        v-else-if="addOnPurchaseFetchError"
        data-testid="add-on-purchase-fetch-error"
        :error="addOnPurchaseFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        class="gl-mt-5"
      />
      <code-suggestions-intro v-else />
    </template>
  </section>
</template>

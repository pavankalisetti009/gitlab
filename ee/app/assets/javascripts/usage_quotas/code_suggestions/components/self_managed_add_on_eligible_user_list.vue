<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DEFAULT_PER_PAGE } from '~/api';
import { fetchPolicies } from '~/lib/graphql';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/self_managed_add_on_eligible_users.query.graphql';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import {
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  DUO_PRO,
  DUO_ENTERPRISE,
  SORT_OPTIONS,
  DEFAULT_SORT_OPTION,
} from 'ee/usage_quotas/code_suggestions/constants';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';

export default {
  name: 'SelfManagedAddOnEligibleUserList',
  components: {
    SearchAndSortBar,
    ErrorAlert,
    AddOnEligibleUserList,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (value) => [DUO_PRO, DUO_ENTERPRISE].includes(value),
    },
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  data() {
    return {
      addOnEligibleUsers: undefined,
      addOnEligibleUsersFetchError: undefined,
      pageInfo: undefined,
      pageSize: DEFAULT_PER_PAGE,
      pagination: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
      filterOptions: {},
      sort: DEFAULT_SORT_OPTION,
    };
  },
  apollo: {
    addOnEligibleUsers: {
      query: getAddOnEligibleUsers,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      nextFetchPolicy: fetchPolicies.CACHE_FIRST,
      variables() {
        return this.queryVariables;
      },
      update({ selfManagedAddOnEligibleUsers }) {
        this.pageInfo = selfManagedAddOnEligibleUsers?.pageInfo;
        return selfManagedAddOnEligibleUsers?.nodes;
      },
      error(error) {
        this.handleAddOnUsersFetchError(error);
      },
    },
  },
  computed: {
    sortOptions() {
      return this.glFeatures.enableAddOnUsersFiltering ? SORT_OPTIONS : [];
    },
    queryVariables() {
      return {
        addOnType:
          this.duoTier === DUO_ENTERPRISE ? ADD_ON_DUO_ENTERPRISE : ADD_ON_CODE_SUGGESTIONS,
        addOnPurchaseIds: [this.addOnPurchaseId],
        sort: this.sort,
        ...this.filterOptions,
        ...this.pagination,
      };
    },
  },
  methods: {
    clearAddOnEligibleUsersFetchError() {
      this.addOnEligibleUsersFetchError = undefined;
    },
    handleAddOnUsersFetchError(error) {
      this.addOnEligibleUsersFetchError = ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE;
      Sentry.captureException(error);
    },
    handleNext(endCursor) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        before: null,
        after: endCursor,
      };
    },
    handlePrev(startCursor) {
      this.pagination = {
        first: null,
        last: this.pageSize,
        before: startCursor,
        after: null,
      };
    },
    handleFilter(filterOptions) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        after: null,
        before: null,
      };
      this.filterOptions = filterOptions;
    },
    handleSort(sort) {
      this.sort = sort;
    },
  },
};
</script>

<template>
  <add-on-eligible-user-list
    :add-on-purchase-id="addOnPurchaseId"
    :users="addOnEligibleUsers"
    :is-loading="$apollo.loading"
    :page-info="pageInfo"
    :search="filterOptions.search"
    :duo-tier="duoTier"
    @next="handleNext"
    @prev="handlePrev"
  >
    <template #search-and-sort-bar>
      <search-and-sort-bar
        :sort-options="sortOptions"
        @onFilter="handleFilter"
        @onSort="handleSort"
      />
    </template>
    <template #error-alert>
      <error-alert
        v-if="addOnEligibleUsersFetchError"
        data-testid="add-on-eligible-users-fetch-error"
        :error="addOnEligibleUsersFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        :dismissible="true"
        @dismiss="clearAddOnEligibleUsersFetchError"
      />
    </template>
  </add-on-eligible-user-list>
</template>

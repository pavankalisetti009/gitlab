<script>
import {
  GlButton,
  GlFilteredSearch,
  GlFilteredSearchToken,
  GlPagination,
  GlSorting,
} from '@gitlab/ui';
import { mapActions, mapState } from 'pinia';
import { __, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  OPERATORS_AFTER_BEFORE,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import DateToken from '~/vue_shared/components/filtered_search_bar/tokens/date_token.vue';
import { SORT_OPTIONS } from '~/access_tokens/constants';

import { useAccessTokens } from '../../stores/access_tokens';
import AccessToken from './access_token.vue';
import AccessTokenForm from './access_token_form.vue';
import AccessTokenTable from './access_token_table.vue';

export default {
  components: {
    GlButton,
    GlFilteredSearch,
    GlPagination,
    GlSorting,
    PageHeading,
    AccessToken,
    AccessTokenForm,
    AccessTokenTable,
  },
  inject: ['accessTokenCreate', 'accessTokenRevoke', 'accessTokenRotate', 'accessTokenShow'],
  props: {
    id: {
      type: Number,
      required: true,
    },
  },
  computed: {
    ...mapState(useAccessTokens, [
      'busy',
      'filters',
      'page',
      'perPage',
      'showCreateForm',
      'sorting',
      'token',
      'tokens',
      'total',
    ]),
  },
  created() {
    this.setup({
      filters: [
        {
          type: 'state',
          value: {
            data: 'active',
            operator: '=',
          },
        },
      ],
      id: this.id,
      urlCreate: this.accessTokenCreate,
      urlRevoke: this.accessTokenRevoke,
      urlRotate: this.accessTokenRotate,
      urlShow: this.accessTokenShow,
    });
    this.fetchTokens();
  },
  methods: {
    ...mapActions(useAccessTokens, [
      'fetchTokens',
      'setFilters',
      'setPage',
      'setShowCreateForm',
      'setSorting',
      'setToken',
      'setup',
    ]),
    addAccessToken() {
      this.setToken(null);
      this.setShowCreateForm(true);
    },
    search(filters) {
      this.setFilters(filters);
      this.setPage(1);
      this.fetchTokens();
    },
    async pageChanged(page) {
      this.setPage(page);
      await this.fetchTokens();
      window.scrollTo({ top: 0 });
    },
    handleSortChange(value) {
      this.setSorting({ value, isAsc: this.sorting.isAsc });
      this.fetchTokens();
    },
    handleSortDirectionChange(isAsc) {
      if (this.sorting.value === 'expires') {
        return;
      }
      this.setSorting({ value: this.sorting.value, isAsc });
      this.fetchTokens();
    },
  },
  fields: [
    {
      icon: 'status',
      title: s__('AccessTokens|State'),
      type: 'state',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: [
        { value: 'active', title: s__('AccessTokens|Active') },
        { value: 'inactive', title: s__('AccessTokens|Inactive') },
      ],
    },
    {
      icon: 'remove',
      title: s__('AccessTokens|Revoked'),
      type: 'revoked',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: [
        { value: 'true', title: __('Yes') },
        { value: 'false', title: __('No') },
      ],
    },
    {
      icon: 'history',
      title: s__('AccessTokens|Created date'),
      type: 'created',
      token: DateToken,
      operators: OPERATORS_AFTER_BEFORE,
      unique: true,
    },
    {
      icon: 'history',
      title: s__('AccessTokens|Expiration date'),
      type: 'expires',
      token: DateToken,
      operators: OPERATORS_AFTER_BEFORE,
      unique: true,
    },
    {
      icon: 'history',
      title: s__('AccessTokens|Last used date'),
      type: 'last_used',
      token: DateToken,
      operators: OPERATORS_AFTER_BEFORE,
      unique: true,
    },
  ],
  SORT_OPTIONS,
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AccessTokens|Personal access tokens')">
      <template #description>
        {{
          s__(
            'AccessTokens|You can generate a personal access token for each application you use that needs access to the GitLab API. You can also use personal access tokens to authenticate against Git over HTTP. They are the only accepted password when you have Two-Factor Authentication (2FA) enabled.',
          )
        }}
      </template>
      <template #actions>
        <gl-button variant="confirm" data-testid="add-new-token-button" @click="addAccessToken">
          {{ s__('AccessTokens|Add new token') }}
        </gl-button>
      </template>
    </page-heading>
    <access-token v-if="token" />
    <access-token-form v-if="showCreateForm" />
    <div class="gl-flex gl-flex-col gl-gap-3 gl-py-5 md:gl-flex-row">
      <gl-filtered-search
        class="gl-min-w-0 gl-grow"
        :value="filters"
        :placeholder="s__('AccessTokens|Search or filter access tokens…')"
        :available-tokens="$options.fields"
        filtered-search-term-key="search"
        terms-as-tokens
        @submit="search"
      />
      <gl-sorting
        block
        dropdown-class="gl-w-full  !gl-flex"
        :is-ascending="sorting.isAsc"
        :sort-by="sorting.value"
        :sort-options="$options.SORT_OPTIONS"
        @sortByChange="handleSortChange"
        @sortDirectionChange="handleSortDirectionChange"
      />
    </div>
    <access-token-table :busy="busy" :tokens="tokens" />
    <gl-pagination
      :value="page"
      :per-page="perPage"
      :total-items="total"
      :disabled="busy"
      align="center"
      class="gl-mt-5"
      @input="pageChanged"
    />
  </div>
</template>

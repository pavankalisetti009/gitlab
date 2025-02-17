<script>
import { GlFilteredSearch, GlFilteredSearchToken, GlPagination } from '@gitlab/ui';
import { mapActions, mapState } from 'pinia';
import { __, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  OPERATORS_AFTER_BEFORE,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import DateToken from '~/vue_shared/components/filtered_search_bar/tokens/date_token.vue';

import { useAccessTokens } from '../../stores/access_tokens';
import AccessTokenTable from './access_token_table.vue';

export default {
  components: {
    GlFilteredSearch,
    GlPagination,
    PageHeading,
    AccessTokenTable,
  },
  inject: ['accessTokenShow'],
  props: {
    id: {
      type: Number,
      required: true,
    },
  },
  computed: {
    ...mapState(useAccessTokens, ['busy', 'filters', 'page', 'perPage', 'tokens', 'total']),
  },
  created() {
    this.setup({
      id: this.id,
      filters: [
        {
          type: 'state',
          value: {
            data: 'active',
            operator: '=',
          },
        },
      ],
      urlShow: this.accessTokenShow,
    });
    this.fetchTokens();
  },
  methods: {
    ...mapActions(useAccessTokens, ['fetchTokens', 'setPage', 'setFilters', 'setup']),
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
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AccessTokens|Personal access tokens')" />
    <gl-filtered-search
      :value="filters"
      :placeholder="s__('AccessTokens|Search or filter access tokens...')"
      :available-tokens="$options.fields"
      filtered-search-term-key="search"
      terms-as-tokens
      class="gl-my-5"
      @submit="search"
    />
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

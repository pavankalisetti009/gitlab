<script>
import { pick } from 'lodash';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  TOKEN_TITLE_ASSIGNEE,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import MilestoneToken from '~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';
import UserToken from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';
import {
  prepareTokens,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import searchLabelsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/search_labels.query.graphql';
import {
  FILTERED_SEARCH_MAX_LABELS,
  FILTERED_SEARCH_OPERATORS,
  FILTERED_SEARCH_SUPPORTED_TOKENS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

export default {
  name: 'FilteredSearchFilter',
  components: {
    FilteredSearchBar,
  },
  inject: {
    namespaceFullPath: {
      type: String,
      default: '',
    },
    isProject: {
      type: Boolean,
    },
    hasScopedLabelsFeature: {
      type: Boolean,
      default: false,
    },
  },
  props: {
    options: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialFilterValue: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  computed: {
    namespaceType() {
      return this.isProject ? 'project' : 'group';
    },
    defaultTokens() {
      const { isProject, namespaceFullPath: fullPath } = this;

      return [
        {
          icon: 'milestone',
          title: TOKEN_TITLE_MILESTONE,
          type: TOKEN_TYPE_MILESTONE,
          token: MilestoneToken,
          unique: true,
          symbol: '%',
          fullPath,
          isProject,
        },
        {
          icon: 'labels',
          title: TOKEN_TITLE_LABEL,
          type: TOKEN_TYPE_LABEL,
          token: LabelToken,
          unique: false,
          symbol: '~',
          maxSuggestions: FILTERED_SEARCH_MAX_LABELS,
          fetchLabels: this.fetchLabels,
        },
        {
          icon: 'pencil',
          title: TOKEN_TITLE_AUTHOR,
          type: TOKEN_TYPE_AUTHOR,
          token: UserToken,
          dataType: 'user',
          unique: true,
          fullPath,
          isProject,
        },
        {
          icon: 'user',
          title: TOKEN_TITLE_ASSIGNEE,
          type: TOKEN_TYPE_ASSIGNEE,
          token: UserToken,
          dataType: 'user',
          unique: false,
          fullPath,
          isProject,
        },
      ];
    },
    tokens() {
      const { options, defaultTokens } = this;

      if (!options.length) return defaultTokens;

      return defaultTokens.reduce((acc, defaultToken) => {
        const tokenOption = options.find(({ token }) => token === defaultToken.type);

        if (tokenOption) {
          const { token, operator, ...restTokenOptionProps } = tokenOption;
          const operators = FILTERED_SEARCH_OPERATORS[operator];

          return [...acc, { ...defaultToken, operators, ...restTokenOptionProps }];
        }

        return acc;
      }, []);
    },
    formattedInitialFilterValue() {
      return prepareTokens(this.initialFilterValue);
    },
  },
  methods: {
    handleFilter(filters) {
      const sanitizedFilters = pick(processFilters(filters), FILTERED_SEARCH_SUPPORTED_TOKENS);

      this.$emit('change', sanitizedFilters);
    },
    fetchLabels(search) {
      return this.$apollo
        .query({
          query: searchLabelsQuery,
          variables: {
            search,
            fullPath: this.namespaceFullPath,
            isProject: this.isProject,
          },
        })
        .then(({ data }) => data?.[this.namespaceType]?.labels?.nodes ?? []);
    },
  },
};
</script>

<template>
  <filtered-search-bar
    :tokens="tokens"
    :namespace="namespaceFullPath"
    :initial-filter-value="formattedInitialFilterValue"
    recent-searches-storage-key="analytics-dashboard"
    :search-input-placeholder="__('Filter results')"
    terms-as-tokens
    @onFilter="handleFilter"
  />
</template>

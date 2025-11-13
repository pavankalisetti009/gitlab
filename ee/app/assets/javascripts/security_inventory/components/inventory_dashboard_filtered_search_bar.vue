<script>
import { s__ } from '~/locale';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { queryToObject } from '~/lib/utils/url_utility';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN } from 'ee/vulnerabilities/constants';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';
import { ATTRIBUTE_TOKEN_PREFIX } from 'ee/security_configuration/security_attributes/components/shared/attribute_constants';
import {
  getAttributeHeaderToken,
  getAttributeCategoryTokens,
} from 'ee/security_configuration/security_attributes/components/shared/attribute_utils';
import {
  DEPENDENCY_SCANNING_KEY,
  SAST_KEY,
  SAST_ADVANCED_KEY,
  SECRET_DETECTION_KEY,
  SECRET_PUSH_PROTECTION_KEY,
  CONTAINER_SCANNING_KEY,
  CONTAINER_SCANNING_FOR_REGISTRY_KEY,
  DAST_KEY,
  SAST_IAC_KEY,
  SEVERITY_FILTER_OPERATOR_TO_CONST,
} from '../constants';
import { toolCoverageTokens } from './tool_coverage_tokens';
import { vulnerabilityCountTokens } from './vulnerability_count_tokens';

export default {
  name: 'InventoryDashboardFilteredSearchBar',
  components: {
    FilteredSearch,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    initialFilters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    namespace: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      initialSortBy: 'updated_at_desc',
      filterParams: {},
      securityCategories: [],
    };
  },
  apollo: {
    securityCategories: {
      query: getSecurityCategoriesAndAttributes,
      variables() {
        return {
          fullPath: this.namespace,
        };
      },
      update: (data) => data?.group?.securityCategories,
    },
  },
  computed: {
    searchTokens() {
      const tokens = [];
      if (this.glFeatures.securityInventoryFiltering) {
        tokens.push(
          getAttributeHeaderToken(
            this.securityCategories,
            s__('SecurityAttributes|Security attributes'),
          ),
          ...getAttributeCategoryTokens(this.securityCategories),
        );
        tokens.push(...vulnerabilityCountTokens, ...toolCoverageTokens);
        return tokens;
      }
      return [];
    },
    initialFilterValue() {
      if (this.initialFilters.search) {
        return [this.initialFilters.search];
      }
      const searchParam = queryToObject(window.location.search).search;
      return searchParam ? [searchParam] : [];
    },
  },
  methods: {
    onFilter(filters = []) {
      const filterParams = {
        vulnerabilityCountFilters: [],
        securityAnalyzerFilters: [],
        attributeFilters: [],
      };
      const plainText = [];

      filters.forEach((filter) => {
        if (!filter.value.data) return;

        if (filter.type === FILTERED_SEARCH_TERM) {
          plainText.push(filter.value.data);
        } else if (
          [
            DEPENDENCY_SCANNING_KEY,
            SAST_KEY,
            SAST_ADVANCED_KEY,
            SECRET_DETECTION_KEY,
            SECRET_PUSH_PROTECTION_KEY,
            CONTAINER_SCANNING_KEY,
            CONTAINER_SCANNING_FOR_REGISTRY_KEY,
            DAST_KEY,
            SAST_IAC_KEY,
          ].includes(filter.type)
        ) {
          filterParams.securityAnalyzerFilters.push({
            analyzerType: filter.type,
            status: filter.value.data,
          });
        } else if ([CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN].includes(filter.type)) {
          filterParams.vulnerabilityCountFilters.push({
            severity: filter.type.toUpperCase(),
            operator: SEVERITY_FILTER_OPERATOR_TO_CONST[filter.value.operator],
            count: parseInt(filter.value.data, 10) || 0,
          });
        } else if (filter.type.startsWith(ATTRIBUTE_TOKEN_PREFIX)) {
          filterParams.attributeFilters.push({
            operator: filter.value.operator === '!=' ? 'IS_NOT_ONE_OF' : 'IS_ONE_OF',
            attributes: filter.value.data,
          });
        }
      });

      if (plainText.length) {
        filterParams.search = plainText.join(' ');
      }

      this.filterParams = { ...filterParams };
      this.$emit('filterSubgroupsAndProjects', this.filterParams);
    },
  },
};
</script>

<template>
  <filtered-search
    class="gl-pr-3"
    v-bind="$attrs"
    :namespace="namespace"
    :initial-filter-value="initialFilterValue"
    :tokens="searchTokens"
    :initial-sort-by="initialSortBy"
    :search-input-placeholder="s__('SecurityInventoryFilter|Search projects…')"
    :search-text-option-label="s__('SecurityInventoryFilter|Search for project name')"
    terms-as-tokens
    @onFilter="onFilter"
  />
</template>

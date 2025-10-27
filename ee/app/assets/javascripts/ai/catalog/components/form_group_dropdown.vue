<script>
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import produce from 'immer';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import getGroups from '~/graphql_shared/queries/get_users_groups.query.graphql';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';

const MINIMUM_QUERY_LENGTH = 3;
const GROUPS_PER_PAGE = 20;

export default {
  name: 'FormGroupDropdown',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
    isValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoadingInitial: true,
      isLoadingMore: false,
      groups: [],
      searchTerm: '',
    };
  },
  apollo: {
    groups: {
      query: getGroups,
      variables() {
        return {
          ...this.queryVariables,
        };
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
      update(data) {
        return data?.groups || [];
      },
      result() {
        this.isLoadingInitial = false;
      },
      error() {
        this.onError();
      },
    },
  },
  computed: {
    queryVariables() {
      return {
        topLevelOnly: true,
        ownedOnly: true,
        search: this.searchTerm,
        first: GROUPS_PER_PAGE,
        sort: 'similarity',
      };
    },
    isLoading() {
      return this.$apollo.queries.groups.loading && !this.isLoadingMore;
    },
    isSearchQueryTooShort() {
      return this.searchTerm && this.searchTerm.length < MINIMUM_QUERY_LENGTH;
    },
    noResultsText() {
      return this.isSearchQueryTooShort
        ? __('Enter at least three characters to search')
        : __('No results found');
    },
    selectedGroup() {
      return this.groups?.nodes?.find((group) => this.value === group.id);
    },
    dropdownText() {
      return this.selectedGroup?.fullName || __('Select a group');
    },
    groupList() {
      if (this.isSearchQueryTooShort) {
        return [];
      }

      return (this.groups?.nodes || []).map((group) => ({
        ...group,
        text: group.fullName,
        value: String(group.id),
      }));
    },
    hasNextPage() {
      return this.groups?.pageInfo?.hasNextPage;
    },
  },
  methods: {
    async onBottomReached() {
      if (!this.hasNextPage) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.groups.fetchMore({
          variables: {
            ...this.queryVariables,
            after: this.groups.pageInfo?.endCursor,
          },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              draftData.groups.nodes = [...previousResult.groups.nodes, ...draftData.groups.nodes];
            });
          },
        });
      } catch (error) {
        this.onError();
      } finally {
        this.isLoadingMore = false;
      }
    },
    onError() {
      this.$emit('error', __('Failed to load groups.'));
    },
    onSearch: debounce(function debouncedSearch(query) {
      this.searchTerm = query;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onGroupSelect(groupId) {
      this.$emit('input', groupId);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="value"
    :items="groupList"
    :toggle-id="id"
    :toggle-text="dropdownText"
    :toggle-class="{ 'gl-shadow-inner-1-red-500': !isValid }"
    :header-text="__('Select a group')"
    :loading="isLoadingInitial"
    searchable
    :searching="isLoading"
    :no-results-text="noResultsText"
    block
    fluid-width
    is-check-centered
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="isLoadingMore"
    :disabled="disabled"
    data-testid="group-select"
    @bottom-reached="onBottomReached"
    @search="onSearch"
    @select="onGroupSelect"
  >
    <template #list-item="{ item: group }">
      <gl-avatar-labeled
        v-if="group"
        :shape="$options.AVATAR_SHAPE_OPTION_RECT"
        :size="32"
        :src="group.avatarUrl"
        :label="group.name"
        :entity-name="group.name"
        :sub-label="group.fullPath"
      />
    </template>
  </gl-collapsible-listbox>
</template>

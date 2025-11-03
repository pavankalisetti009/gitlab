<script>
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import produce from 'immer';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { MINIMUM_QUERY_LENGTH, PAGE_SIZE } from '../constants';

export default {
  name: 'SingleSelectDropdown',
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
    query: {
      type: Object,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
    dataKey: {
      type: String,
      required: true,
    },
    placeholderText: {
      type: String,
      required: true,
    },
    searchable: {
      type: Boolean,
      required: false,
      default: false,
    },
    itemTextFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    itemLabelFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    itemSubLabelFn: {
      type: Function,
      required: false,
      default: () => {},
    },
  },
  emits: ['input', 'error'],
  data() {
    return {
      isLoadingInitial: true,
      isLoadingMore: false,
      items: [],
      searchTerm: '',
    };
  },
  apollo: {
    items: {
      query() {
        return this.query;
      },
      variables() {
        return {
          ...this.queryVariables,
          search: this.searchTerm,
          first: PAGE_SIZE,
        };
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
      update(data) {
        return data?.[this.dataKey] || [];
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
    isLoading() {
      return this.$apollo.queries.items.loading && !this.isLoadingMore;
    },
    isSearchQueryTooShort() {
      return this.searchTerm && this.searchTerm.length < MINIMUM_QUERY_LENGTH;
    },
    noResultsText() {
      return this.isSearchQueryTooShort
        ? __('Enter at least three characters to search')
        : __('No results found');
    },
    selectedItem() {
      return this.items?.nodes?.find((item) => this.value === item.id);
    },
    dropdownText() {
      return this.itemText(this.selectedItem) || this.placeholderText;
    },
    itemList() {
      if (this.isSearchQueryTooShort) {
        return [];
      }

      return (this.items?.nodes || []).map((item) => ({
        ...item,
        text: this.itemText(item),
        value: String(item.id),
      }));
    },
    hasNextPage() {
      return this.items?.pageInfo?.hasNextPage;
    },
  },
  methods: {
    itemText(item) {
      return this.itemTextFn(item);
    },
    itemLabel(item) {
      return this.itemLabelFn(item);
    },
    itemSubLabel(item) {
      return this.itemSubLabelFn(item);
    },
    async onBottomReached() {
      if (!this.hasNextPage) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.items.fetchMore({
          variables: {
            ...this.queryVariables,
            search: this.searchTerm,
            first: PAGE_SIZE,
            after: this.items.pageInfo?.endCursor,
          },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              draftData[this.dataKey].nodes = [
                ...previousResult[this.dataKey].nodes,
                ...draftData[this.dataKey].nodes,
              ];
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
      this.$emit('error');
    },
    onSearch: debounce(function debouncedSearch(query) {
      this.searchTerm = query;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onItemSelect(itemId) {
      const selectedItem = this.items?.nodes?.find((item) => itemId === item.id);
      this.$emit('input', selectedItem);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="value"
    :items="itemList"
    :toggle-id="id"
    :toggle-text="dropdownText"
    :toggle-class="{ 'gl-shadow-inner-1-red-500': !isValid }"
    :header-text="placeholderText"
    :loading="isLoadingInitial"
    :searchable="searchable"
    :searching="isLoading"
    :no-results-text="noResultsText"
    block
    fluid-width
    is-check-centered
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="isLoadingMore"
    :disabled="disabled"
    @bottom-reached="onBottomReached"
    @search="onSearch"
    @select="onItemSelect"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        v-if="item"
        :shape="$options.AVATAR_SHAPE_OPTION_RECT"
        :size="32"
        :src="item.avatarUrl"
        :label="itemLabel(item)"
        :entity-name="itemLabel(item)"
        :sub-label="itemSubLabel(item)"
      />
    </template>
  </gl-collapsible-listbox>
</template>

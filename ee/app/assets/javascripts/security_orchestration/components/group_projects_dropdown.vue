<script>
import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';
import { debounce, uniqBy } from 'lodash';
import produce from 'immer';
import { __ } from '~/locale';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_for_policies.query.graphql';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import getProjects from 'ee/security_orchestration/graphql/queries/get_projects.query.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  i18n: {
    projectDropdownHeader: __('Select projects'),
    groupDropdownHeader: __('Select groups'),
    selectAllLabel: __('Select all'),
    clearAllLabel: __('Clear all'),
  },
  name: 'GroupProjectsDropdown',
  components: {
    GlCollapsibleListbox,
    GlTruncate,
  },
  apollo: {
    groups: {
      query: getGroups,
      variables() {
        return {
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all groups that have been loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        return uniqBy([...this.groups, ...data.groups.nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = data?.groups?.pageInfo || {};
      },
      error() {
        this.$emit('groups-query-error');
      },
      skip() {
        return !this.groupsOnly;
      },
    },
    projects: {
      query() {
        return this.loadAllProjects ? getProjects : getGroupProjects;
      },
      variables() {
        return {
          ...(this.loadAllProjects ? {} : { fullPath: this.groupFullPath }),
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        const payload = this.loadAllProjects ? data.projects.nodes : data.group.projects.nodes;
        return uniqBy([...this.projects, ...payload], 'id');
      },
      result({ data }) {
        const payload = this.loadAllProjects ? data?.projects : data?.group?.projects;
        this.pageInfo = payload?.pageInfo || {};
      },
      error() {
        this.$emit('projects-query-error');
      },
      skip() {
        return this.groupsOnly;
      },
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupFullPath: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupsOnly: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    loadAllProjects: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      pageInfo: {},
      searchTerm: '',
      projects: [],
      groups: [],
    };
  },
  computed: {
    itemsQuery() {
      return this.$apollo.queries[this.groupsOnly ? 'groups' : 'projects'];
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
    },
    items() {
      return this.groupsOnly ? this.groups : this.filteredProjects;
    },
    headerText() {
      return this.groupsOnly
        ? this.$options.i18n.groupDropdownHeader
        : this.$options.i18n.projectDropdownHeader;
    },
    formattedSelectedIds() {
      return this.multiple ? this.selected : [this.selected];
    },
    existingFormattedSelectedIds() {
      if (this.multiple) {
        return this.selected.filter((id) => this.itemsIds.includes(id));
      }

      return this.selected;
    },
    dropdownPlaceholder() {
      return renderMultiSelectText({
        selected: this.formattedSelectedIds,
        items: this.labelItems,
        itemTypeName: this.groupsOnly ? __('groups') : __('projects'),
        useAllSelected: !this.hasNextPage,
      });
    },
    loading() {
      return this.itemsQuery.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    labelItems() {
      return this.items?.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    listBoxItems() {
      const items = this.items.map(({ id, fullPath, name }) => ({
        text: name,
        value: id,
        fullPath,
      }));
      return searchInItemsProperties({ items, properties: ['text'], searchQuery: this.searchTerm });
    },
    itemsIds() {
      return this.items.map(({ id }) => id);
    },
    resetButtonLabel() {
      return this.multiple ? this.$options.i18n.clearAllLabel : '';
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    fetchMoreItems() {
      const { groupsOnly } = this;
      const variables = {
        after: this.pageInfo.endCursor,
        fullPath: this.groupFullPath,
      };

      this.itemsQuery
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              if (groupsOnly) {
                draftData.group.descendantGroups.nodes = [
                  ...previousResult.group.descendantGroups.nodes,
                  ...draftData.group.descendantGroups.nodes,
                ];
              } else {
                draftData.group.projects.nodes = [
                  ...previousResult.group.projects.nodes,
                  ...draftData.group.projects.nodes,
                ];
              }
            });
          },
        })
        .catch(() => {
          this.$emit('projects-query-error');
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const ids = this.multiple ? selected : [selected];
      const selectedItems = this.items.filter(({ id }) => ids.includes(id));
      const payload = this.multiple ? selectedItems : selectedItems[0];
      this.$emit('select', payload);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    is-check-centered
    searchable
    fluid-width
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="headerText"
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="loading"
    :reset-button-label="resetButtonLabel"
    :show-select-all-button-label="$options.i18n.selectAllLabel"
    :searching="searching"
    :selected="existingFormattedSelectedIds"
    :placement="placement"
    :items="listBoxItems"
    :toggle-text="dropdownPlaceholder"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems(itemsIds)"
  >
    <template #list-item="{ item }">
      <span :class="['gl-block', { 'gl-font-bold': item.fullPath }]">
        <gl-truncate :text="item.text" with-tooltip />
      </span>
      <span v-if="item.fullPath" class="gl-mt-1 gl-block gl-text-sm gl-text-gray-700">
        <gl-truncate position="middle" :text="item.fullPath" with-tooltip />
      </span>
    </template>
  </gl-collapsible-listbox>
</template>

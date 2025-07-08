<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { getTypeFromGraphQLId } from '~/graphql_shared/utils';

import { AUDIT_STREAMS_FILTERING } from '../../constants';
import getNamespaceFiltersQuery from '../../graphql/queries/get_namespace_filters.query.graphql';
import getInstanceNamespaceFiltersQuery from '../../graphql/queries/get_instance_namespace_filters.query.graphql';

export default {
  components: {
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
      filterTargets: null,
    };
  },
  apollo: {
    filterTargets: {
      query() {
        return this.isInstance ? getInstanceNamespaceFiltersQuery : getNamespaceFiltersQuery;
      },
      variables() {
        if (this.isInstance) {
          return {
            search: this.searchTerm,
          };
        }
        return {
          search: this.searchTerm,
          fullPath: this.groupPath,
        };
      },
      update(data) {
        if (this.isInstance) {
          return {
            groups: data.groups?.nodes || [],
            projects: data.projects?.nodes || [],
          };
        }
        return {
          groups: data.group?.descendantGroups?.nodes || [],
          projects: data.group?.projects?.nodes || [],
        };
      },
      skip() {
        // Skip query if component is not yet mounted or if groupPath is not available
        return !this.groupPath;
      },
    },
  },
  computed: {
    isInstance() {
      return this.groupPath === 'instance';
    },
    selectedEntry() {
      if (!this.filterTargets) {
        return null;
      }

      return [...this.filterTargets.groups, ...this.filterTargets.projects].find(
        (n) => n.fullPath === this.value?.namespace,
      );
    },
    selectedId() {
      return this.selectedEntry?.id;
    },
    options() {
      const result = [];
      if (this.filterTargets?.groups?.length > 0) {
        result.push({
          text: __('Groups'),
          options: this.filterTargets.groups.map((g) => ({
            text: g.name,
            value: g.id,
            secondaryText: g.fullPath,
          })),
        });
      }
      if (this.filterTargets?.projects?.length > 0) {
        result.push({
          text: __('Projects'),
          options: this.filterTargets.projects.map((p) => ({
            text: p.name,
            value: p.id,
            secondaryText: p.fullPath,
          })),
        });
      }
      return result;
    },
    toggleText() {
      if (!this.value?.namespace) {
        return this.$options.i18n.SELECT_NAMESPACE;
      }

      return this.selectedEntry?.name || this.value.namespace;
    },
    isLoading() {
      return this.$apollo.queries.filterTargets?.loading || false;
    },
  },
  methods: {
    updateSearchTerm(searchTerm) {
      this.searchTerm = searchTerm;
    },
    selectOption(selectedId) {
      if (!selectedId) {
        this.resetOptions();
        return;
      }

      const type = getTypeFromGraphQLId(selectedId);
      const allItems = [
        ...(this.filterTargets?.groups || []),
        ...(this.filterTargets?.projects || []),
      ];
      const selectedItem = allItems.find((item) => item.id === selectedId);

      if (!selectedItem) {
        return;
      }

      const namespaceType = type === 'Group' ? 'group' : 'project';
      this.$emit('input', { namespace: selectedItem.fullPath, type: namespaceType });
    },
    resetOptions() {
      this.$emit('input', { namespace: '', type: '' });
    },
  },
  i18n: AUDIT_STREAMS_FILTERING,
};
</script>

<template>
  <gl-collapsible-listbox
    id="audit-event-namespace-filter"
    :items="options"
    :selected="selectedId"
    :header-text="$options.i18n.SELECT_NAMESPACE"
    :show-select-all-button-label="$options.i18n.SELECT_ALL"
    :reset-button-label="$options.i18n.UNSELECT_ALL"
    :no-results-text="$options.i18n.NO_RESULT_TEXT"
    :search-placeholder="$options.i18n.SEARCH_PLACEHOLDER"
    searchable
    :searching="isLoading"
    toggle-class="gl-max-w-full"
    :toggle-text="toggleText"
    class="gl-max-w-full"
    data-testid="namespace-filter-dropdown"
    @select="selectOption"
    @reset="resetOptions"
    @search="updateSearchTerm"
  />
</template>

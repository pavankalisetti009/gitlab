<script>
import { GlTooltipDirective, GlIcon, GlSprintf } from '@gitlab/ui';
import { debounce, uniqBy, get } from 'lodash';
import produce from 'immer';
import { n__, __ } from '~/locale';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  i18n: {
    projectDropdownHeader: __('Select projects'),
    footerTooltipText: __('Scroll to the bottom to load more projects'),
    footerTextTemplate: __('%{loadedProjects} of %{totalProjectsCount} %{projects} loaded'),
  },
  name: 'GroupProjectsDropdown',
  directives: { GlTooltip: GlTooltipDirective },
  components: {
    BaseItemsDropdown,
    GlIcon,
    GlSprintf,
  },
  apollo: {
    projects: {
      query() {
        return getGroupProjects;
      },
      variables() {
        return this.reactiveVariables;
      },
      update(data) {
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        const nodes = get(data, 'group.projects.nodes', []);
        return uniqBy([...this.projects, ...nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = get(data, 'group.projects.pageInfo', {});
        if (!this.allProjectsCountSaved) {
          this.allProjectsCount = get(data, 'group.projects.count', 0);
        }

        if (this.selectedButNotLoadedProjectIds.length > 0) {
          this.fetchGroupProjectsByIds();
        }
      },
      error() {
        this.$emit('projects-query-error');
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
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    withProjectCount: {
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
      allProjectsCount: 0,
    };
  },
  computed: {
    allProjectsCountSaved() {
      return this.allProjectsCount > 0;
    },
    projectIds() {
      return this.filteredProjects?.map(({ id }) => id);
    },
    selectedButNotLoadedProjectIds() {
      const selected = this.multiple ? this.selected : [this.selected];
      return selected.filter((id) => !this.projectIds.includes(id));
    },
    showFooter() {
      return this.withProjectCount && !this.loading;
    },
    allProjectsLoaded() {
      return this.projects.length === this.allProjectsCount;
    },
    projectsText() {
      return n__('project', 'projects', this.allProjectsCount);
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
    },
    items() {
      return this.filteredProjects;
    },
    itemTypeName() {
      return this.isGroup ? __('groups') : __('projects');
    },
    existingFormattedSelectedIds() {
      if (this.multiple) {
        return this.selected.filter((id) => this.projectIds.includes(id));
      }

      return this.selected;
    },
    loading() {
      return this.$apollo.queries.projects.loading;
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
    listBoxItems() {
      const items = this.items.map(({ id, fullPath, name }) => ({
        text: name,
        value: id,
        fullPath,
      }));

      return searchInItemsProperties({
        items,
        properties: ['text', 'fullPath'],
        searchQuery: this.searchTerm,
      });
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    pathVariable() {
      return { fullPath: this.groupFullPath, withCount: this.withProjectCount };
    },
    reactiveVariables() {
      const baseVariables = {
        ...this.pathVariable,
      };

      /**
       * When all projects were loaded
       * there is no need for a backend search
       */
      if (this.allProjectsLoaded) {
        return baseVariables;
      }

      return {
        ...this.pathVariable,
        search: this.searchTerm,
      };
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchGroupProjectsByIds() {
      const variables = {
        after: this.pageInfo.endCursor,
        projectIds: this.selectedButNotLoadedProjectIds,
        ...this.pathVariable,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getGroupProjects,
          variables,
        });
        const { projects: { nodes = [] } = {} } = data.group || {};
        this.projects = uniqBy([...this.projects, ...nodes], 'id');
      } catch {
        this.$emit('projects-query-error');
      }
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        ...this.pathVariable,
      };

      this.$apollo.queries.projects
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const getSourceObject = (source) => {
                return get(source, 'group.projects');
              };

              getSourceObject(draftData).nodes = [
                ...getSourceObject(previousResult).nodes,
                ...getSourceObject(draftData).nodes,
              ];
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
  <base-items-dropdown
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="$options.i18n.projectDropdownHeader"
    :items="listBoxItems"
    :infinite-scroll="hasNextPage"
    :searching="searching"
    :selected="existingFormattedSelectedIds"
    :placement="placement"
    :item-type-name="itemTypeName"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  >
    <template v-if="showFooter" #footer>
      <div
        class="gl-border-t gl-flex gl-items-center gl-gap-3 gl-px-4 gl-py-3"
        data-testid="footer"
      >
        <div>
          <span>
            <gl-sprintf :message="$options.i18n.footerTextTemplate">
              <template #loadedProjects>
                <strong>{{ listBoxItems.length }}</strong>
              </template>
              <template #totalProjectsCount>
                <strong>{{ allProjectsCount }}</strong>
              </template>
              <template #projects>
                {{ projectsText }}
              </template>
            </gl-sprintf>
          </span>
          <span
            ><gl-icon
              v-if="!allProjectsLoaded"
              v-gl-tooltip
              name="information-o"
              variant="info"
              :title="$options.i18n.footerTooltipText"
          /></span>
        </div>
      </div>
    </template>
  </base-items-dropdown>
</template>

<script>
import { debounce } from 'lodash';
import produce from 'immer';
import {
  GlAvatarLabeled,
  GlButton,
  GlCollapsibleListbox,
  GlDropdownDivider,
  GlDropdownItem,
} from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { s__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import Api from 'ee/api';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';

export default {
  name: 'CentralizedSecurityPolicyManagement',
  apollo: {
    groups: {
      query: getGroups,
      variables() {
        return {
          search: this.searchValue,
          topLevelOnly: true,
        };
      },
      update(data) {
        return (
          data.groups?.nodes?.map((group) => {
            const id = getIdFromGraphQLId(group.id);
            return {
              ...group,
              id,
              value: id,
              text: group.fullPath,
            };
          }) || []
        );
      },
      result({ data }) {
        this.pageInfo = data.groups?.pageInfo || {};

        // If not searching, select existing group if it exists
        if (!this.searchValue && this.selectedGroupId) {
          this.selectedGroup = this.groups.find((group) => group.id === this.selectedGroupId);

          if (!this.selectedGroup) {
            this.loadMoreGroups(this.selectedGroupId);
          }
        }
      },
    },
  },
  components: {
    GlAvatarLabeled,
    GlButton,
    GlCollapsibleListbox,
    GlDropdownDivider,
    GlDropdownItem,
  },
  props: {
    formId: {
      type: String,
      required: true,
    },
    selectedGroupId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      groups: [],
      pageInfo: {},
      saving: false,
      searchValue: '',
      selectedGroup: { id: '' },
    };
  },
  computed: {
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    loading() {
      return this.$apollo.queries.groups.loading || this.saving;
    },
    toggleText() {
      return this.selectedGroup.fullName || s__('SecurityOrchestration|Select a group');
    },
  },
  created() {
    this.handleSearch = debounce(this.setSearchValue, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleSearch.cancel();
  },
  methods: {
    async loadMoreGroups(id) {
      if (!this.hasNextPage) return [];

      try {
        return await this.$apollo.queries.groups.fetchMore({
          variables: {
            ...(id ? { ids: [convertToGraphQLId(TYPENAME_GROUP, id)] } : {}),
            search: this.searchValue,
            after: this.pageInfo.endCursor,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.groups.nodes = [
                ...previousResult.groups.nodes,
                ...fetchMoreResult.groups.nodes,
              ];
            });
          },
        });
      } catch {
        return [];
      }
    },
    setSearchValue(value = '') {
      this.searchValue = value;
    },
    async assignGroup(groupId) {
      this.saving = true;
      try {
        await Api.updatePolicySettings({
          csp_namespace_id: groupId,
        });
        document.getElementById(this.formId).submit();
      } catch (error) {
        this.saving = false;
      }
    },
    handleSelect(groupId) {
      this.selectedGroup = this.groups.find((group) => group.id === groupId);
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      data-testid="exceptions-selector"
      is-check-centered
      searchable
      :items="groups"
      :infinite-scroll="hasNextPage"
      :loading="loading"
      :selected="selectedGroup.id"
      :toggle-text="toggleText"
      @bottom-reached="loadMoreGroups"
      @search="handleSearch"
      @select="handleSelect"
    >
      <template #list-item="{ item }">
        <gl-avatar-labeled
          :entity-name="item.fullName"
          :label="item.fullName"
          :size="32"
          :src="item.avatarUrl"
          :sub-label="item.fullPath"
        />
      </template>

      <template #footer>
        <gl-dropdown-divider />
        <gl-dropdown-item
          class="gl-list-none"
          data-testid="unassign-button"
          :disabled="loading || !selectedGroupId"
          @click="assignGroup(null)"
        >
          {{ s__('SecurityOrchestration|Unassign group') }}
        </gl-dropdown-item>
      </template>
    </gl-collapsible-listbox>
    <div>
      <gl-button
        data-testid="save-button"
        class="gl-mt-5"
        category="primary"
        variant="confirm"
        :disabled="loading"
        @click="assignGroup(selectedGroup.id)"
      >
        {{ s__('SecurityOrchestration|Save changes') }}
      </gl-button>
    </div>
  </div>
</template>

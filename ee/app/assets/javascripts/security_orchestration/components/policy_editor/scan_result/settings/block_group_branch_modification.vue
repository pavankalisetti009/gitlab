<script>
import { debounce } from 'lodash';
import {
  GlAvatarLabeled,
  GlCollapsibleListbox,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import Api from '~/api';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { __, s__ } from '~/locale';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION_WITH_EXCEPTIONS_HUMANIZED_STRING,
  BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING,
} from '../lib';
import {
  EXCEPT_GROUPS,
  EXCEPTION_GROUPS_TEXTS,
  EXCEPTION_GROUPS_LISTBOX_ITEMS,
  WITHOUT_EXCEPTIONS,
  createGroupObject,
  fetchExistingGroups,
  updateSelectedGroups,
} from '../lib/settings';

export default {
  name: 'BlockGroupBranchModification',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
    GlLink,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      groups: [],
      loading: false,
      selectedExceptionType: this.exceptions.length ? EXCEPT_GROUPS : WITHOUT_EXCEPTIONS,
      selectedGroups: [],
    };
  },
  computed: {
    exceptionItems() {
      return this.exceptions.map(({ id }) => id);
    },
    text() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS
        ? BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING
        : BLOCK_GROUP_BRANCH_MODIFICATION_WITH_EXCEPTIONS_HUMANIZED_STRING;
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.selectedGroups,
        selected: this.exceptionItems,
        placeholder: __('Select groups'),
        maxOptionsShown: 2,
      });
    },
  },
  watch: {
    enabled(value) {
      if (value) {
        this.selectExceptionType(this.selectedExceptionType);
      } else {
        this.selectExceptionType(WITHOUT_EXCEPTIONS);
      }
    },
    async exceptionItems(ids) {
      const availableGroups = [...this.selectedGroups, ...this.groups];
      this.selectedGroups = await updateSelectedGroups({ ids, availableGroups });
    },
  },
  created() {
    this.handleSearch = debounce(this.fetchGroups, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  async mounted() {
    this.selectedGroups = await fetchExistingGroups(this.exceptionItems);
    await this.fetchGroups();
  },
  methods: {
    async fetchGroups(searchValue = '') {
      this.loading = true;

      try {
        const topLevelGroups = await Api.groups(searchValue, { top_level_only: true });
        this.groups = topLevelGroups.map((group) => createGroupObject(group));
      } catch {
        this.groups = [];
        createAlert({
          message: s__('SecurityOrchestration|Something went wrong, unable to fetch groups'),
        });
      } finally {
        this.loading = false;
      }
    },
    selectExceptionType(type) {
      this.selectedExceptionType = type;

      if (this.enabled) {
        const value =
          type === EXCEPT_GROUPS
            ? { enabled: this.enabled, exceptions: this.exceptions }
            : this.enabled;
        this.emitChangeEvent(value);
      }
    },
    updateGroupExceptionValue(ids) {
      if (this.enabled) {
        this.emitChangeEvent({ enabled: this.enabled, exceptions: ids.map((id) => ({ id })) });
      }
    },
    emitChangeEvent(value) {
      this.$emit('change', value);
    },
  },

  GROUP_PROTECTED_BRANCHES_DOCS: helpPagePath('user/project/repository/branches/protected', {
    anchor: 'for-all-projects-in-a-group',
  }),
  EXCEPTION_GROUPS_TEXTS,
  EXCEPTION_GROUPS_LISTBOX_ITEMS,
};
</script>

<template>
  <div>
    <gl-sprintf :message="text">
      <template #link="{ content }">
        <gl-link :href="$options.GROUP_PROTECTED_BRANCHES_DOCS" target="_blank">{{
          content
        }}</gl-link>
      </template>
      <template #exceptSelection>
        <gl-collapsible-listbox
          data-testid="has-exceptions-selector"
          class="gl-my-3 gl-mr-2 md:gl-my-0"
          :disabled="!enabled"
          :items="$options.EXCEPTION_GROUPS_LISTBOX_ITEMS"
          :selected="selectedExceptionType"
          @select="selectExceptionType"
        />
      </template>
      <template #groupSelection>
        <gl-collapsible-listbox
          data-testid="exceptions-selector"
          is-check-centered
          multiple
          searchable
          :items="groups"
          :loading="loading"
          :selected="exceptionItems"
          :toggle-text="toggleText"
          @search="handleSearch"
          @select="updateGroupExceptionValue"
        >
          <template #list-item="{ item }">
            <gl-avatar-labeled
              shape="circle"
              :size="32"
              :src="item.avatar_url"
              :entity-name="item.text"
              :label="item.text"
              :sub-label="item.full_path"
            />
          </template>
        </gl-collapsible-listbox>
      </template>
    </gl-sprintf>
  </div>
</template>

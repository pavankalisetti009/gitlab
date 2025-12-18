<script>
import {
  GlBadge,
  GlFilteredSearchToken,
  GlDropdownDivider,
  GlDropdownSectionHeader,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';
import SearchSuggestion from '../components/search_suggestion.vue';

export default {
  name: 'TrackedRefToken',
  defaultValues: ({ trackedRefs = [] }) => {
    const defaultRef = trackedRefs.find((ref) => ref.isDefault);
    return defaultRef ? [defaultRef.id] : [];
  },
  transformFilters: (filters) => {
    const trackedRefIds = filters.filter((value) => value !== ALL_ID);
    return {
      trackedRefIds,
    };
  },
  transformQueryParams: (filters) => {
    return filters.length > 0 ? filters.join(',') : ALL_ID;
  },
  components: {
    GlBadge,
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    SearchSuggestion,
  },
  inject: {
    trackedRefs: {
      default: () => [],
    },
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const defaultRefId = this.trackedRefs.find((ref) => ref.isDefault)?.id;
    const hasData = this.value.data?.length > 0;

    if (hasData) {
      return { selectedRefIds: this.value.data };
    }

    if (defaultRefId) {
      return { selectedRefIds: [defaultRefId] };
    }

    if (this.config.multiSelect) {
      return { selectedRefIds: [ALL_ID] };
    }

    return { selectedRefIds: [] };
  },
  computed: {
    isMultiSelect() {
      return this.config.multiSelect;
    },
    tokenValue() {
      return {
        ...this.value,
        data: this.active ? null : this.selectedRefIds,
      };
    },
    refGroups() {
      const branchOptions = this.getRefByType('branch').map(this.createOption);
      const tagOptions = this.getRefByType('tag').map(this.createOption);

      const groups = [];

      if (this.isMultiSelect) {
        groups.push({
          text: '',
          options: [
            {
              value: ALL_ID,
              text: s__('SecurityReports|All tracked refs'),
            },
          ],
        });
      }

      if (branchOptions.length) {
        groups.push({
          text: s__('SecurityReports|Branches'),
          options: branchOptions,
          icon: 'branch',
        });
      }

      if (tagOptions.length) {
        groups.push({
          text: s__('SecurityReports|Tags'),
          options: tagOptions,
          icon: 'tag',
        });
      }

      return groups;
    },
    allRefItems() {
      const refOptions = this.trackedRefs.map((ref) => ({
        value: ref.id,
        text: ref.name,
      }));

      if (!this.isMultiSelect) {
        return refOptions;
      }

      const allOption = {
        value: ALL_ID,
        text: s__('SecurityReports|All tracked refs'),
      };

      return [allOption, ...refOptions];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.allRefItems,
        selected: this.selectedRefIds,
        placeholder: this.isMultiSelect
          ? s__('SecurityReports|All tracked refs')
          : s__('SecurityReports|Select a ref'),
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    getRefByType(type) {
      return this.trackedRefs.filter((ref) => ref.refType.toLowerCase() === type);
    },
    createOption(ref) {
      return {
        value: ref.id,
        text: ref.name,
      };
    },
    updateSelected(refId) {
      const allRefsSelected = refId === ALL_ID;
      if (allRefsSelected) {
        this.selectedRefIds = [ALL_ID];
        return;
      }

      // Single-select mode: replace selection
      if (!this.isMultiSelect) {
        this.selectedRefIds = [refId];
        return;
      }

      // Multi-select mode: toggle selection
      const isSelecting = !this.selectedRefIds.includes(refId);
      if (isSelecting) {
        this.selectedRefIds = this.selectedRefIds.filter((id) => id !== ALL_ID).concat(refId);
      } else {
        this.selectedRefIds = this.selectedRefIds.filter((id) => id !== refId);
      }

      if (this.selectedRefIds.length === 0) {
        this.selectedRefIds = [ALL_ID];
      }
    },
    isRefIdSelected(refId) {
      return this.selectedRefIds.includes(refId);
    },
  },
  i18n: {
    label: s__('SecurityReports|Tracked ref'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedRefIds"
    :value="tokenValue"
    v-on="$listeners"
    @select="updateSelected"
  >
    <template #view>
      <span data-testid="toggle-text">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <template v-for="(group, index) in refGroups">
        <gl-dropdown-section-header v-if="group.text" :key="group.text">
          <div class="gl-flex gl-items-center gl-justify-center">
            <div class="gl-grow">{{ group.text }}</div>
            <gl-badge v-if="group.icon" :icon="group.icon" variant="neutral" aria-hidden="true" />
          </div>
        </gl-dropdown-section-header>
        <search-suggestion
          v-for="ref in group.options"
          :key="ref.value"
          :value="ref.value"
          :text="ref.text"
          :selected="isRefIdSelected(ref.value)"
          :data-testid="`suggestion-${ref.value}`"
        />
        <gl-dropdown-divider v-if="index < refGroups.length - 1" :key="`divider-${group.text}`" />
      </template>
    </template>
  </gl-filtered-search-token>
</template>

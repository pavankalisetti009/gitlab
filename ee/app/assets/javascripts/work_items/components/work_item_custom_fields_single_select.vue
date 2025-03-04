<script>
import { GlTruncate, GlTooltipDirective } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { __, sprintf } from '~/locale';
import { formatSelectOptionForCustomField } from '~/work_items/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  sprintfWorkItem,
  I18N_WORK_ITEM_ERROR_UPDATING,
} from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';

export default {
  components: {
    GlTruncate,
    WorkItemSidebarDropdownWidget,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: false,
      default: '',
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    customField: {
      type: Object,
      required: true,
      validator: (customField) => {
        return (
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_SINGLE_SELECT &&
          (customField.selectedOptions === null || Array.isArray(customField.selectedOptions))
        );
      },
    },
  },
  data() {
    return {
      searchTerm: '',
      searchStarted: false,
      isUpdating: false,
      selectedOption: null,
    };
  },
  computed: {
    customFieldId() {
      return this.customField.customField?.id;
    },
    dropdownLabel() {
      return this.customField.customField?.name;
    },
    headerText() {
      return sprintf(__('Select %{name}'), { name: this.dropdownLabel });
    },
    editingValueText() {
      return this.selectedOption?.text || __('None');
    },
    visibleOptions() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.defaultOptions, this.searchTerm, {
          key: ['text'],
        });
      }

      return this.defaultOptions;
    },
    optionsList() {
      const visibleOptions = this.visibleOptions || [];

      if (this.searchTerm || !this.optionValue) {
        return visibleOptions;
      }

      const unselectedOptions = visibleOptions.filter(
        ({ value }) => value !== this.selectedOption?.value,
      );

      return [
        { options: [this.selectedOption], text: __('Selected') },
        { options: unselectedOptions, text: __('All'), textSrOnly: true },
      ];
    },
    optionValue() {
      return this.selectedOption?.value;
    },
    defaultOptions() {
      return (
        this.customField.customField?.selectOptions?.map(formatSelectOptionForCustomField) || []
      );
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_SINGLE_SELECT;
    },
    isValueValid() {
      return (
        this.customField.selectedOptions === null || Array.isArray(this.customField.selectedOptions)
      );
    },
  },
  watch: {
    customField: {
      immediate: true,
      handler(customField) {
        if (this.isValueValid) {
          this.selectedOption = customField.selectedOptions?.map(
            formatSelectOptionForCustomField,
          )?.[0];
        }
      },
    },
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.searchStarted = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.searchStarted = true;
    },
    async updateSelectedOption(selectedOptionId) {
      if (!this.canUpdate) return;

      this.isUpdating = true;

      this.selectedOption = selectedOptionId
        ? this.defaultOptions.find(({ value }) => value === selectedOptionId)
        : null;

      this.$apollo
        .mutate({
          mutation: updateWorkItemCustomFieldsMutation,
          variables: {
            input: {
              id: this.workItemId,
              customFieldsWidget: {
                customFieldId: this.customFieldId,
                selectedOptionIds: [selectedOptionId],
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    v-if="displayWidget"
    :key="customFieldId"
    dropdown-name="single-select"
    :dropdown-label="dropdownLabel"
    :can-update="canUpdate"
    :list-items="optionsList"
    :item-value="optionValue"
    :toggle-dropdown-text="editingValueText"
    :header-text="headerText"
    :update-in-progress="isUpdating"
    clear-search-on-item-select
    @dropdownShown="onDropdownShown"
    @searchStarted="search"
    @updateValue="updateSelectedOption"
  >
    <template #list-item="{ item }">
      <span class="gl-break-words">{{ item.text }}</span>
    </template>
    <template #readonly>
      <span v-gl-tooltip :title="editingValueText">
        <gl-truncate :text="editingValueText" />
      </span>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>

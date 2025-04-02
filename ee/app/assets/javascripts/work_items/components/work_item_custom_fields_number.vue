<script>
import { GlButton, GlForm, GlFormInput, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { newWorkItemId } from '~/work_items/utils';
import {
  CUSTOM_FIELDS_TYPE_NUMBER,
  sprintfWorkItem,
  I18N_WORK_ITEM_ERROR_UPDATING,
} from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';

export default {
  inputId: 'custom-field-number-input',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlForm,
    GlFormInput,
    GlLoadingIcon,
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
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_NUMBER &&
          (customField.value == null || Number.isFinite(Number(customField.value)))
        );
      },
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      value: this.customField.value,
      isEditing: false,
      isUpdating: false,
    };
  },
  computed: {
    customFieldId() {
      return this.customField.customField?.id;
    },
    customFieldName() {
      return this.customField.customField?.name;
    },
    hasValue() {
      return this.value !== null && Number.isFinite(Number(this.value));
    },
    showRemoveValue() {
      return this.hasValue && !this.isUpdating;
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_NUMBER;
    },
  },
  watch: {
    customField: {
      immediate: true,
      handler(customField) {
        this.value = customField.value;
      },
    },
  },
  methods: {
    blurInput() {
      this.$refs.input.$el.blur();
    },
    updateNumberFromInput() {
      if (this.value === '' || !this.value) {
        this.updateNumber(null);
        return;
      }

      const value = Number(this.value);
      this.updateNumber(value);
    },
    async updateNumber(number) {
      if (this.clickingClearButton) return;
      if (!this.canUpdate) return;

      this.isUpdating = true;
      this.isEditing = false;

      // Create work item flow
      if (this.workItemId === newWorkItemId(this.workItemType)) {
        await this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              workItemType: this.workItemType,
              fullPath: this.fullPath,
              customField: {
                id: this.customFieldId,
                numberValue: number,
              },
            },
          },
        });

        this.isUpdating = false;
        return;
      }

      await this.$apollo
        .mutate({
          mutation: updateWorkItemCustomFieldsMutation,
          variables: {
            input: {
              id: this.workItemId,
              customFieldsWidget: [
                {
                  customFieldId: this.customFieldId,
                  numberValue: number,
                },
              ],
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
          // Send error event up to work_item_detail to show alert on page
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
          this.isEditing = false;
        });
    },
  },
};
</script>

<template>
  <div v-if="displayWidget">
    <div class="gl-flex gl-items-center gl-justify-between">
      <!-- hide header when editing, since we then have a form label. Keep it reachable for screenreader nav  -->
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-heading-5 !gl-mb-0">
        {{ customFieldName }}
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-number"
        class="flex-shrink-0"
        category="tertiary"
        size="small"
        @click="isEditing = true"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <gl-form v-if="isEditing" @submit.prevent="blurInput">
      <div class="gl-flex gl-items-center">
        <label :for="$options.inputId" class="gl-mb-0">{{ customFieldName }}</label>
        <gl-loading-icon v-if="isUpdating" size="sm" inline class="gl-ml-3" />
        <gl-button
          data-testid="apply-number"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="isEditing = false"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <!-- wrapper for the form input so the borders fit inside the sidebar -->
      <div class="gl-relative gl-px-2">
        <gl-form-input
          :id="$options.inputId"
          ref="input"
          v-model="value"
          min="0"
          class="hide-unfocused-input-decoration gl-block"
          type="number"
          :disabled="isUpdating"
          :placeholder="__('Enter a number')"
          autofocus
          @blur="updateNumberFromInput"
          @keydown.exact.esc.stop="blurInput"
        />
        <gl-button
          v-if="showRemoveValue"
          v-gl-tooltip
          category="tertiary"
          size="small"
          icon="clear"
          class="gl-clear-icon-button gl-absolute gl-right-7 gl-top-2"
          :title="__('Remove number')"
          :aria-label="__('Remove number')"
          @mousedown="clickingClearButton = true"
          @mouseup="clickingClearButton = false"
          @click="updateNumber(null)"
        />
      </div>
    </gl-form>
    <template v-else-if="hasValue">
      <div data-testid="custom-field-value">{{ value }}</div>
    </template>
    <template v-else>
      <div class="gl-text-subtle" data-testid="custom-field-value">{{ __('None') }}</div>
    </template>
  </div>
</template>

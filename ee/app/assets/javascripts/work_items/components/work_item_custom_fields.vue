<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  WIDGET_TYPE_CUSTOM_FIELDS,
  CUSTOM_FIELDS_TYPE_NUMBER,
  CUSTOM_FIELDS_TYPE_TEXT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  I18N_WORK_ITEM_FETCH_CUSTOM_FIELDS_ERROR,
} from '~/work_items/constants';
import workItemCustomFieldsQuery from '../graphql/work_item_custom_fields.query.graphql';
import WorkItemCustomFieldNumber from './work_item_custom_fields_number.vue';
import WorkItemCustomFieldText from './work_item_custom_fields_text.vue';
import WorkItemCustomFieldSingleSelect from './work_item_custom_fields_single_select.vue';
import WorkItemCustomFieldMultiSelect from './work_item_custom_fields_multi_select.vue';

export default {
  components: {
    WorkItemCustomFieldNumber,
    WorkItemCustomFieldText,
    WorkItemCustomFieldSingleSelect,
    WorkItemCustomFieldMultiSelect,
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
    fullPath: {
      type: String,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      workItemCustomFields: [],
    };
  },
  apollo: {
    workItemCustomFields: {
      query() {
        return workItemCustomFieldsQuery;
      },
      variables() {
        return {
          id: this.workItemId,
        };
      },
      skip() {
        return !this.workItemId;
      },
      update(data) {
        return (
          data.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_CUSTOM_FIELDS)
            ?.customFieldValues ?? []
        );
      },
      error(error) {
        this.$emit('error', I18N_WORK_ITEM_FETCH_CUSTOM_FIELDS_ERROR);
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    hasCustomFields() {
      return this.workItemCustomFields.length > 0;
    },
  },
  methods: {
    customFieldComponent(customField) {
      switch (customField.fieldType) {
        case CUSTOM_FIELDS_TYPE_NUMBER:
          return WorkItemCustomFieldNumber;
        case CUSTOM_FIELDS_TYPE_TEXT:
          return WorkItemCustomFieldText;
        case CUSTOM_FIELDS_TYPE_SINGLE_SELECT:
          return WorkItemCustomFieldSingleSelect;
        case CUSTOM_FIELDS_TYPE_MULTI_SELECT:
          return WorkItemCustomFieldMultiSelect;
        default:
          Sentry.captureException(new Error(`Unknown custom field type: ${customField.fieldType}`));
          return null;
      }
    },
  },
};
</script>

<template>
  <div v-if="hasCustomFields" data-testid="work-item-custom-field">
    <component
      :is="customFieldComponent(customFieldData.customField)"
      v-for="customFieldData in workItemCustomFields"
      :key="customFieldData.customField.id"
      class="gl-border-t gl-mb-5 gl-border-subtle gl-pt-5"
      :custom-field="customFieldData"
      :can-update="canUpdate"
      :work-item-type="workItemType"
      :full-path="fullPath"
    />
  </div>
</template>

<script>
import { __ } from '~/locale';
import getGroups from '~/graphql_shared/queries/get_users_groups.query.graphql';
import SingleSelectDropdown from './single_select_dropdown.vue';

export default {
  name: 'FormGroupDropdown',
  components: {
    SingleSelectDropdown,
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
  },
  computed: {
    query() {
      return getGroups;
    },
    queryVariables() {
      return {
        topLevelOnly: true,
        ownedOnly: true,
        sort: 'similarity',
      };
    },
  },
  methods: {
    itemTextFn(item) {
      return item?.fullName;
    },
    itemLabelFn(item) {
      return item?.name;
    },
    itemSubLabelFn(item) {
      return item?.fullPath;
    },
    onInput(item) {
      this.$emit('input', item.id);
    },
    onError() {
      this.$emit('error', __('Failed to load groups.'));
    },
  },
};
</script>

<template>
  <single-select-dropdown
    :id="id"
    :value="value"
    :is-valid="isValid"
    :disabled="disabled"
    :query="query"
    :query-variables="queryVariables"
    data-key="groups"
    :placeholder-text="__('Select a group')"
    :item-text-fn="itemTextFn"
    :item-label-fn="itemLabelFn"
    :item-sub-label-fn="itemSubLabelFn"
    @input="onInput"
    @error="onError"
  />
</template>

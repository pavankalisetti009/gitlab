<script>
import { __ } from '~/locale';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import SingleSelectDropdown from './single_select_dropdown.vue';

export default {
  name: 'FormProjectDropdown',
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
  query: getProjects,
  queryVariables: {
    minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
    sort: 'similarity',
  },
  methods: {
    itemTextFn(item) {
      return item?.nameWithNamespace;
    },
    itemLabelFn(item) {
      return item?.name;
    },
    itemSubLabelFn(item) {
      return item?.nameWithNamespace;
    },
    onInput(item) {
      this.$emit('input', item.id);
    },
    onError() {
      this.$emit('error', __('Failed to load projects'));
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
    :query="$options.query"
    :query-variables="$options.queryVariables"
    data-key="projects"
    :placeholder-text="__('Select a project')"
    searchable
    :item-text-fn="itemTextFn"
    :item-label-fn="itemLabelFn"
    :item-sub-label-fn="itemSubLabelFn"
    @input="onInput"
    @error="onError"
  />
</template>

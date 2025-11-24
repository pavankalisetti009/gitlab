<script>
import { sprintf } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';

export default {
  name: 'GroupItemConsumerDropdown',
  components: {
    SingleSelectDropdown,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    rootGroupId: {
      default: null,
    },
  },
  props: {
    dropdownTexts: {
      type: Object,
      required: true,
    },
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
    itemTypes: {
      type: Array,
      required: true,
    },
  },
  query: aiCatalogConfiguredItemsQuery,
  computed: {
    queryVariables() {
      return {
        groupId: convertToGraphQLId(TYPENAME_GROUP, this.rootGroupId),
        itemTypes: this.itemTypes,
        first: PAGE_SIZE,
        after: null,
        before: null,
        last: null,
      };
    },
  },
  methods: {
    itemTextFn(item) {
      return item?.item?.name;
    },
    itemLabelFn(item) {
      return item?.item?.name;
    },
    itemSubLabelFn(item) {
      return sprintf(this.dropdownTexts.itemSublabel, {
        id: getIdFromGraphQLId(item?.item?.id),
      });
    },
    onInput(item) {
      this.$emit('input', item);
    },
    onError() {
      this.$emit('error');
    },
  },
};
</script>

<template>
  <single-select-dropdown
    :id="id"
    :value="value"
    :is-valid="isValid"
    :query="$options.query"
    :query-variables="queryVariables"
    data-key="aiCatalogConfiguredItems"
    :placeholder-text="dropdownTexts.placeholder"
    :item-text-fn="itemTextFn"
    :item-label-fn="itemLabelFn"
    :item-sub-label-fn="itemSubLabelFn"
    @input="onInput"
    @error="onError"
  />
</template>

<script>
import { s__, sprintf } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import { createAvailableFlowItemTypes } from 'ee/ai/catalog/utils';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';

export default {
  name: 'AiCatalogGroupFlowDropdown',
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
    itemTypes() {
      return createAvailableFlowItemTypes({
        isFlowsEnabled: this.glFeatures.aiCatalogFlows,
        isThirdPartyFlowsEnabled: this.glFeatures.aiCatalogThirdPartyFlows,
      });
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
      return sprintf(s__('AICatalog|Flow ID: %{id}'), {
        id: getIdFromGraphQLId(item?.item?.id),
      });
    },
    onInput(item) {
      this.$emit('input', item);
    },
    onError() {
      this.$emit('error', s__('AICatalog|Failed to load group flows'));
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
    :placeholder-text="s__('AICatalog|Select a flow')"
    :item-text-fn="itemTextFn"
    :item-label-fn="itemLabelFn"
    :item-sub-label-fn="itemSubLabelFn"
    @input="onInput"
    @error="onError"
  />
</template>

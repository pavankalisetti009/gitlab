<script>
import { GlTableLite, GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import DeleteSelfHostedModelDisclosureItem from './delete_self_hosted_model_disclosure_item.vue';

export default {
  name: 'SelfHostedModelsTable',
  components: {
    GlTableLite,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    DeleteSelfHostedModelDisclosureItem,
  },
  props: {
    models: {
      type: Array,
      required: true,
    },
    basePath: {
      type: String,
      required: true,
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('AdminSelfHostedModels|Name'),
      thClass: 'gl-w-2/8',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model',
      label: s__('AdminSelfHostedModels|Model'),
      thClass: 'gl-w-2/8',
      tdClass: 'gl-content-center',
    },
    {
      key: 'endpoint',
      label: s__('AdminSelfHostedModels|Endpoint'),
      thClass: 'gl-w-2/8',
      tdClass: 'gl-content-center gl-text-ellipsis',
    },
    {
      key: 'has_api_key',
      label: s__('AdminSelfHostedModels|API token'),
      thClass: 'gl-w-1/8 gl-text-center',
      tdClass: 'gl-content-center gl-text-center',
    },
    {
      key: 'edit',
      label: '',
      thClass: 'gl-w-1/8',
      tdClass: 'gl-content-center gl-text-right',
    },
  ],
  methods: {
    editModelItem(model) {
      return {
        text: __('Edit'),
        to: `${this.basePath}/${getIdFromGraphQLId(model.id)}/edit`,
      };
    },
  },
};
</script>
<template>
  <gl-table-lite
    data-testid="self-hosted-model-table"
    :fields="$options.fields"
    :items="models"
    stacked="md"
    :hover="true"
    :selectable="false"
  >
    <template #cell(has_api_key)="{ item }">
      <gl-icon
        v-if="item.hasApiToken"
        :aria-label="s__('AdminSelfHostedModels|Model uses an API token')"
        name="check-circle"
      />
    </template>
    <template #cell(edit)="{ item }">
      <gl-disclosure-dropdown
        class="gl-py-2"
        category="tertiary"
        size="small"
        icon="ellipsis_v"
        :no-caret="true"
      >
        <gl-disclosure-dropdown-item data-testid="model-edit-button" :item="editModelItem(item)" />
        <delete-self-hosted-model-disclosure-item :model="item" />
      </gl-disclosure-dropdown>
    </template>
  </gl-table-lite>
</template>

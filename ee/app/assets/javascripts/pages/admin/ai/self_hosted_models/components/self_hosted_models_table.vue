<script>
import {
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import DeleteSelfHostedModelDisclosureItem from './delete_self_hosted_model_disclosure_item.vue';

export default {
  name: 'SelfHostedModelsTable',
  components: {
    GlTable,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlLink,
    GlSprintf,
    DeleteSelfHostedModelDisclosureItem,
  },
  inject: ['basePath', 'newSelfHostedModelPath'],
  props: {
    models: {
      type: Array,
      required: true,
    },
  },
  i18n: {
    emptyStateText: s__(
      'AdminSelfHostedModels|You do not currently have any self-hosted models. %{linkStart}Add a self-hosted model%{linkEnd} to get started.',
    ),
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
      key: 'identifier',
      label: __('Model identifier'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
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
  <gl-table
    data-testid="self-hosted-model-table"
    :fields="$options.fields"
    :items="models"
    stacked="md"
    :hover="true"
    :selectable="false"
    :show-empty="true"
  >
    <template #empty>
      <p class="gl-m-0 gl-py-4">
        <gl-sprintf :message="$options.i18n.emptyStateText">
          <template #link="{ content }">
            <gl-link :href="newSelfHostedModelPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </template>
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
  </gl-table>
</template>

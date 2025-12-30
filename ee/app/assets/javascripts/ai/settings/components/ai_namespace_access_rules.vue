<script>
import { GlTable, GlButton, GlFormCheckbox, GlFormGroup, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';

const AVAILABLE_ENTITIES = [
  {
    key: 'duo_classic',
    label: s__('AiPowered|GitLab Duo Classic'),
  },
  {
    key: 'duo_agents',
    label: s__('AiPowered|GitLab Duo Agents'),
  },
  {
    key: 'duo_flows',
    label: s__('AiPowered|GitLab Duo Flows and External Agents'),
  },
];

export default {
  name: 'AiNamespaceAccessRules',
  components: {
    GlTable,
    GlButton,
    GlFormGroup,
    GlFormCheckbox,
    GlLink,
  },
  AVAILABLE_ENTITIES,
  fields: [
    {
      key: 'namespaceName',
      label: s__('AiPowered|Group'),
    },
    {
      key: 'enabledFeatures',
      label: s__('AiPowered|Membership grants access to'),
    },
    {
      key: 'actions',
      label: null,
    },
  ],
  props: {
    initialNamespaceAccessRules: {
      type: Array,
      required: false,
      default: null,
    },
  },
  emits: ['change'],
  data() {
    return {
      namespaceAccessRules: this.initialNamespaceAccessRules,
    };
  },
  methods: {
    isEntityEnabled(namespaceAccessRule, entityKey) {
      return namespaceAccessRule?.enabledFeatures?.includes(entityKey) || false;
    },
  },
};
</script>

<template>
  <div v-if="initialNamespaceAccessRules" class="mb-4 gl-max-w-3xl">
    <gl-form-group :label="s__('AiPowered|Member Access')">
      <p class="gl-mb-5 gl-text-secondary">
        {{
          s__('AiPowered|Only members of these groups will have access to selected AI features.')
        }}
        <gl-link href="/help/user/ai_features">
          {{ s__('AiPowered|Learn more') }}
        </gl-link>
      </p>

      <gl-table
        :items="namespaceAccessRules"
        :fields="$options.fields"
        show-empty
        bordered
        thead-class="gl-bg-gray-50"
      >
        <template #empty>
          <div class="gl-my-5 gl-text-center gl-text-secondary">
            {{ s__('AiPowered|No access rules configured.') }}
          </div>
        </template>

        <template #cell(namespaceName)="{ item }">
          <gl-link :href="`/${item.namespacePath}`" target="_blank">
            {{ item.namespaceName }}
          </gl-link>
        </template>

        <template #cell(enabledFeatures)="{ item }">
          <div class="gl-display-flex gl-flex-direction-column gl-gap-3">
            <gl-form-checkbox
              v-for="entity in $options.AVAILABLE_ENTITIES"
              :key="entity.key"
              :checked="isEntityEnabled(item, entity.key)"
              disabled
            >
              {{ entity.label }}
            </gl-form-checkbox>
          </div>
        </template>

        <template #cell(actions)="">
          <gl-button variant="link" category="secondary" disabled>
            {{ s__('AiPowered|Remove') }}
          </gl-button>
        </template>
      </gl-table>

      <gl-button category="secondary" disabled>
        {{ s__('AiPowered|Add Group') }}
      </gl-button>
    </gl-form-group>
  </div>
</template>

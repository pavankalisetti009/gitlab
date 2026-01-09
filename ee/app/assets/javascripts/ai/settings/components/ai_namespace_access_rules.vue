<script>
import { GlTable, GlButton, GlFormCheckbox, GlFormGroup, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';

const AVAILABLE_FEATURES = [
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
  AVAILABLE_FEATURES,
  fields: [
    {
      key: 'namespaceName',
      label: s__('AiPowered|Group'),
    },
    {
      key: 'features',
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
    isFeatureEnabled(namespaceAccessRule, feature) {
      return namespaceAccessRule.features.includes(feature) || false;
    },
  },
};
</script>

<template>
  <div class="gl-mb-4 gl-max-w-3xl">
    <gl-form-group :label="s__('AiPowered|Member access')">
      <p class="gl-mb-5 gl-text-subtle">
        {{
          s__('AiPowered|Only members of these groups will have access to selected AI features.')
        }}
        <!-- This docs link is incorrect and needs to be fixed. Should also use help_page_link.vue component. -->
        <!-- eslint-disable-next-line @gitlab/vue-no-hardcoded-urls -->
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
            {{ s__('AiPowered|No access rules configured') }}
          </div>
        </template>

        <template #cell(namespaceName)="{ item }">
          <gl-link :href="`/${item.throughNamespace.fullPath}`" target="_blank">
            {{ item.throughNamespace.name }}
          </gl-link>
        </template>

        <template #cell(features)="{ item }">
          <div class="gl-display-flex gl-flex-direction-column gl-gap-3">
            <gl-form-checkbox
              v-for="feature in $options.AVAILABLE_FEATURES"
              :key="feature.key"
              :checked="isFeatureEnabled(item, feature.key)"
              disabled
            >
              {{ feature.label }}
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

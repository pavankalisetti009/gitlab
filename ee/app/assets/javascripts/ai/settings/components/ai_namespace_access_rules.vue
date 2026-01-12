<script>
import { GlTable, GlButton, GlFormCheckbox, GlFormGroup, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import GroupSelector from './group_selector.vue';

const AVAILABLE_FEATURES = [
  {
    key: 'duo_classic',
    label: s__('AiPowered|GitLab Duo Classic'),
  },
  {
    key: 'duo_agent_platform',
    label: s__('AiPowered|GitLab Duo Agent Platform'),
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
    GroupSelector,
    HelpPageLink,
  },
  AVAILABLE_FEATURES,
  fields: [
    {
      key: 'namespaceName',
      label: s__('AiPowered|Group'),
      thStyle: { width: '40%' },
      tdClass: 'gl-max-w-0',
    },
    {
      key: 'features',
      label: s__('AiPowered|Membership grants access to'),
      thStyle: { width: '40%' },
      tdClass: 'gl-max-w-0',
    },
    {
      key: 'actions',
      label: null,
      thStyle: { width: '20%' },
      tdClass: 'gl-max-w-0',
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
    onGroupSelected(group) {
      const id = getIdFromGraphQLId(group.id);
      const exists = this.namespaceAccessRules.some((rule) => rule.throughNamespace.id === id);

      if (exists) {
        return;
      }

      this.namespaceAccessRules = [
        ...this.namespaceAccessRules,
        {
          throughNamespace: {
            id,
            name: group.name,
            fullPath: group.fullPath,
          },
          features: AVAILABLE_FEATURES.map((rule) => rule.key),
        },
      ];

      this.$emit('change', this.namespaceAccessRules);
    },
    removeNamespaceAccessRule(namespaceId) {
      this.namespaceAccessRules = this.namespaceAccessRules.filter(
        (rule) => rule.throughNamespace.id !== namespaceId,
      );

      this.$emit('change', this.namespaceAccessRules);
    },
    toggleFeature(namespaceId, feature, isEnabled) {
      this.namespaceAccessRules = this.namespaceAccessRules.map((rule) => {
        if (rule.throughNamespace.id !== namespaceId) return rule;

        const features = new Set(rule.features);

        if (isEnabled) {
          features.add(feature);
        } else {
          features.delete(feature);
        }

        return {
          ...rule,
          features: [...features],
        };
      });

      this.$emit('change', this.namespaceAccessRules);
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

        <help-page-link
          href="administration/gitlab_duo/configure/access_control.md"
          target="_blank"
        >
          {{ s__('AiPowered|Learn more') }}
        </help-page-link>
      </p>

      <gl-table
        :items="namespaceAccessRules"
        :fields="$options.fields"
        show-empty
        bordered
        fixed
        thead-class="gl-bg-subtle"
      >
        <template #empty>
          <div class="gl-my-5 gl-text-center gl-text-subtle">
            {{ s__('AiPowered|No access rules configured') }}
          </div>
        </template>

        <template #cell(namespaceName)="{ item }">
          <div class="gl-truncate">
            <gl-link :href="`/${item.throughNamespace.fullPath}`" target="_blank">
              {{ item.throughNamespace.name }}
            </gl-link>
          </div>
        </template>

        <template #cell(features)="{ item }">
          <div class="gl-display-flex gl-flex-direction-column gl-gap-3">
            <gl-form-checkbox
              v-for="feature in $options.AVAILABLE_FEATURES"
              :key="feature.key"
              :checked="isFeatureEnabled(item, feature.key)"
              @change="toggleFeature(item.throughNamespace.id, feature.key, $event)"
            >
              {{ feature.label }}
            </gl-form-checkbox>
          </div>
        </template>

        <template #cell(actions)="{ item }">
          <gl-button
            variant="link"
            category="secondary"
            @click="removeNamespaceAccessRule(item.throughNamespace.id)"
          >
            {{ s__('AiPowered|Remove') }}
          </gl-button>
        </template>
      </gl-table>

      <group-selector @group-selected="onGroupSelected" />
    </gl-form-group>
  </div>
</template>

<script>
import { GlBadge } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_LEVEL_PRIVATE_STRING,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_TYPE_ICON,
} from '~/visibility_level/constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    GlBadge,
    AiCatalogItemField,
    FormFlowDefinition,
    FormSection,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    visibility() {
      return this.item.public ? VISIBILITY_LEVEL_PUBLIC_STRING : VISIBILITY_LEVEL_PRIVATE_STRING;
    },
    badgeVariant() {
      return this.item.public ? 'success' : 'warning';
    },
    definition() {
      return this.item.latestVersion?.definition;
    },
    steps() {
      return (
        this.item.latestVersion?.steps?.nodes?.map(({ agent }) => ({
          agent: { name: agent.name, id: getIdFromGraphQLId(agent.id) },
        })) || []
      );
    },
  },
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">
      {{ s__('AICatalog|Flow configuration') }}
    </h3>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Basic information')">
        <ai-catalog-item-field :title="s__('AICatalog|Display name')" :value="item.name" />
        <ai-catalog-item-field :title="s__('AICatalog|Description')" :value="item.description" />
      </form-section>
      <form-section :title="s__('AICatalog|Access rights')">
        <ai-catalog-item-field :title="s__('AICatalog|Visibility')">
          <div class="gl-text-subtle">
            {{
              s__(
                'AICatalog|Anyone in your organization can view and use flows unless you make it private. Private flows can only be viewed in their source project.',
              )
            }}
          </div>
          <gl-badge
            :icon="$options.VISIBILITY_TYPE_ICON[visibility]"
            :variant="badgeVariant"
            class="gl-mt-3"
          >
            {{ $options.VISIBILITY_LEVEL_LABELS[visibility] }}
          </gl-badge>
        </ai-catalog-item-field>
        <ai-catalog-item-field
          v-if="projectName"
          :title="s__('AICatalog|Source project')"
          :value="projectName"
        />
      </form-section>
      <form-section v-if="definition" :title="s__('AICatalog|Configuration')">
        <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
          <form-flow-definition :value="definition" read-only class="gl-mt-3" />
        </ai-catalog-item-field>
      </form-section>
      <form-section v-else :title="s__('AICatalog|Steps')">
        <ai-catalog-item-field :title="s__('AICatalog|Steps')">
          <div v-for="(step, index) in steps" :key="index">
            {{ step.agent.name }} ({{ step.agent.id }})
          </div>
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>

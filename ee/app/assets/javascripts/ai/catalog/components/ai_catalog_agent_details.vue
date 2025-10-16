<script>
import { GlBadge } from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import FormSection from './form_section.vue';

export default {
  components: {
    GlBadge,
    AiCatalogItemField,
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
    systemPrompt() {
      return this.item.latestVersion?.systemPrompt;
    },
    tools() {
      return this.item.latestVersion?.tools?.nodes
        .map((t) => t.title)
        .sort()
        .join(', ');
    },
  },
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">
      {{ s__('AICatalog|Agent configuration') }}
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
                'AICatalog|Anyone in your organization can view and use agents unless you make it private. Private agents can only be viewed and run in their source project.',
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
      <form-section :title="s__('AICatalog|Prompts')">
        <ai-catalog-item-field v-if="systemPrompt" :title="s__('AICatalog|System prompt')">
          <div class="gl-border gl-mb-3 gl-mt-2 gl-rounded-default gl-bg-default gl-p-3">
            <pre class="gl-m-0 gl-whitespace-pre-wrap">{{ systemPrompt }}</pre>
          </div>
        </ai-catalog-item-field>
      </form-section>
      <form-section v-if="tools" :title="s__('AICatalog|Available tools')">
        <ai-catalog-item-field :title="s__('AICatalog|Tools')" :value="tools" />
      </form-section>
    </dl>
  </div>
</template>

<script>
import { GlBadge } from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_PRIVATE_STRING,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
} from '~/visibility_level/constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';

export default {
  components: {
    GlBadge,
    AiCatalogItemField,
  },
  props: {
    public: {
      type: Boolean,
      required: false,
      default: false,
    },
    descriptionTexts: {
      type: Object,
      required: true,
    },
  },
  computed: {
    visibility() {
      return this.public ? VISIBILITY_LEVEL_PUBLIC_STRING : VISIBILITY_LEVEL_PRIVATE_STRING;
    },
    visibilityDescription() {
      return this.descriptionTexts[this.visibility];
    },
    badgeIcon() {
      return VISIBILITY_TYPE_ICON[this.visibility];
    },
    badgeLabel() {
      return VISIBILITY_LEVEL_LABELS[this.visibility];
    },
    badgeVariant() {
      return this.public ? 'success' : 'warning';
    },
  },
};
</script>

<template>
  <ai-catalog-item-field :title="s__('AICatalog|Visibility')">
    <div class="gl-text-subtle">
      {{ visibilityDescription }}
    </div>
    <gl-badge :icon="badgeIcon" :variant="badgeVariant" class="gl-mt-3">
      {{ badgeLabel }}
    </gl-badge>
  </ai-catalog-item-field>
</template>

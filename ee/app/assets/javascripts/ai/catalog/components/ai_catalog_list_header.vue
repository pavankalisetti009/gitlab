<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogNavTabs from './ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogListHeader',
  components: {
    GlExperimentBadge,
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    isGlobal: {
      default: false,
    },
  },
  props: {
    heading: {
      type: String,
      required: false,
      default: undefined,
    },
    canAdmin: {
      type: Boolean,
      required: false,
      default: true, // this will change when we remove the ability to create item from Explore level
    },
    newButtonVariant: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  computed: {
    title() {
      return this.heading || s__('AICatalog|AI Catalog');
    },
    showActionsForProject() {
      return !this.isGlobal && this.glFeatures.aiCatalogItemProjectCuration;
    },
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div class="gl-flex">
          <span>{{ title }}</span>
          <gl-experiment-badge class="gl-self-center" />
        </div>
      </template>
      <template #actions>
        <ai-catalog-nav-actions v-if="showActionsForProject" :new-button-variant="newButtonVariant">
          <slot name="nav-actions"></slot>
        </ai-catalog-nav-actions>
      </template>
    </page-heading>
    <div v-if="isGlobal" class="gl-border-b gl-flex">
      <ai-catalog-nav-tabs />
      <ai-catalog-nav-actions :can-admin="canAdmin" />
    </div>
  </div>
</template>

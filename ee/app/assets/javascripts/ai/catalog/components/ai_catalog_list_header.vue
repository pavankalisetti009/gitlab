<script>
import { GlExperimentBadge, GlLink, GlIcon, GlModalDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import LinkToDashboardModal, {
  LINK_TO_DASHBOARD_MODAL_ID,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/link_to_dashboards_modal.vue';
import {
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/tracking';
import { AI_IMPACT_DASHBOARD } from 'ee/analytics/analytics_dashboards/constants';
import AiCatalogNavTabs from './ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogListHeader',
  components: {
    GlExperimentBadge,
    GlLink,
    GlIcon,
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
    LinkToDashboardModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  inject: {
    isGlobal: {
      default: false,
    },
    aiImpactDashboardEnabled: {
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
      default: false,
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
  },
  LINK_TO_DASHBOARD_MODAL_ID,
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
  AI_IMPACT_DASHBOARD,
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
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-link
            v-if="aiImpactDashboardEnabled"
            v-gl-modal="$options.LINK_TO_DASHBOARD_MODAL_ID"
            class="gl-flex gl-items-center gl-gap-2"
            :aria-label="s__('AICatalog|Explore your GitLab Duo and SDLC trends')"
            :data-track-action="$options.TRACKING_ACTION_CLICK_DASHBOARD_LINK"
            :data-track-label="$options.TRACKING_LABEL_AI_CATALOG_HEADER"
          >
            <span>{{ s__('AICatalog|Explore your GitLab Duo and SDLC trends') }}</span>
            <gl-icon name="information-o" />
          </gl-link>
          <ai-catalog-nav-actions
            v-if="!isGlobal"
            :can-admin="canAdmin"
            :new-button-variant="newButtonVariant"
          >
            <slot name="nav-actions"></slot>
          </ai-catalog-nav-actions>
        </div>
      </template>
    </page-heading>
    <div v-if="isGlobal" class="gl-border-b gl-flex">
      <ai-catalog-nav-tabs />
      <ai-catalog-nav-actions can-admin />
    </div>

    <link-to-dashboard-modal
      v-if="aiImpactDashboardEnabled"
      :dashboard-name="$options.AI_IMPACT_DASHBOARD"
    />
  </div>
</template>

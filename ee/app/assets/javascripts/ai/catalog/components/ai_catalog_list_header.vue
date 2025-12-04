<script>
import {
  GlExperimentBadge,
  GlLink,
  GlIcon,
  GlModalDirective,
  GlPopover,
  GlSprintf,
} from '@gitlab/ui';
import uniqueId from 'lodash/uniqueId';
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
import { DOCS_URL } from 'jh_else_ce/lib/utils/url_utility';
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
    GlPopover,
    GlSprintf,
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
    aiImpactDashboardDocsLink() {
      return `${DOCS_URL}/user/analytics/duo_and_sdlc_trends/`;
    },
  },
  LINK_TO_DASHBOARD_MODAL_ID,
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
  AI_IMPACT_DASHBOARD,
  AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID: uniqueId('dashboard-link'),
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
          <template v-if="aiImpactDashboardEnabled">
            <gl-link
              v-gl-modal="$options.LINK_TO_DASHBOARD_MODAL_ID"
              class="gl-flex gl-items-center gl-gap-2"
              :aria-label="s__('AICatalog|Explore your GitLab Duo and SDLC trends')"
              :data-track-action="$options.TRACKING_ACTION_CLICK_DASHBOARD_LINK"
              :data-track-label="$options.TRACKING_LABEL_AI_CATALOG_HEADER"
            >
              {{ s__('AICatalog|Explore your GitLab Duo and SDLC trends') }}
            </gl-link>
            <gl-icon :id="$options.AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID" name="information-o" />
            <gl-popover :target="$options.AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID">
              <gl-sprintf
                :message="
                  s__(
                    'AICatalog|This key dashboard provides visibility into SDLC metrics in the context of AI adoption for projects and groups. %{linkStart}Learn more%{linkEnd}',
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="aiImpactDashboardDocsLink" target="_blank" class="!gl-text-sm">
                    {{ content }}</gl-link
                  >
                </template>
              </gl-sprintf>
            </gl-popover>
          </template>
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

<script>
import { GlTabs, GlTab, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import BetaBadge from '~/vue_shared/components/badges/beta_badge.vue';
import SelfHostedModelsPage from './self_hosted_models_page.vue';
import FeatureSettingsPage from './ai_feature_settings_page.vue';
import { SELF_HOSTED_DUO_TABS } from './constants';

export default {
  name: 'SelfHostedDuoConfiguration',
  components: {
    BetaBadge,
    GlTabs,
    GlTab,
    GlButton,
    SelfHostedModelsPage,
    FeatureSettingsPage,
    PageHeading,
  },
  inject: ['newSelfHostedModelPath'],
  i18n: {
    title: s__('AdminSelfHostedModels|Self-hosted models'),
    description: s__(
      'AdminSelfHostedModels|Manage GitLab Duo by configuring and assigning self-hosted models to AI-powered features.',
    ),
  },
  data() {
    return {
      currentTab: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS,
    };
  },
  computed: {
    isSelfHostedModelsTab() {
      return this.currentTab === SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS;
    },
  },
  methods: {
    onTabClick(tab) {
      this.currentTab = tab.value;
    },
  },
  tabs: [
    {
      title: s__('AdminSelfHostedModels|Self-hosted models'),
      value: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS,
    },
    {
      title: s__('AdminAIPoweredFeatures|AI-powered features'),
      value: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS,
    },
  ],
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-center gl-gap-3">
          <span data-testid="self-hosted-title">{{ $options.i18n.title }}</span>
          <beta-badge class="gl-flex" />
        </div>
      </template>
      <template #description>{{ $options.i18n.description }}</template>
      <template #actions>
        <gl-button variant="confirm" :href="newSelfHostedModelPath">
          {{ s__('AdminSelfHostedModels|Add self-hosted model') }}
        </gl-button>
      </template>
    </page-heading>
    <div class="top-area gl-items-center gl-border-b-0">
      <gl-tabs class="gl-flex gl-grow" nav-class="gl-border-b-0">
        <gl-tab
          v-for="tab in $options.tabs"
          :key="tab.id"
          :data-testid="`${tab.value}-tab`"
          @click="onTabClick(tab)"
        >
          <template #title>
            {{ tab.title }}
          </template>
        </gl-tab>
      </gl-tabs>
    </div>
    <div v-if="isSelfHostedModelsTab">
      <self-hosted-models-page />
    </div>
    <div v-else>
      <feature-settings-page />
    </div>
  </div>
</template>

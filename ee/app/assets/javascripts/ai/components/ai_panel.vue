<script>
import { __ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AiContentContainer from './content_container.vue';
import NavigationRail from './navigation_rail.vue';

export default {
  PANEL_EXPANDED_STORAGE_KEY: 'ai-panel-expanded',
  ACTIVE_TAB_KEY: 'ai-panel-active-tab',
  components: {
    AiContentContainer,
    NavigationRail,
    LocalStorageSync,
  },
  data() {
    return {
      isExpanded: true,
      activeTab: localStorage.getItem(this.$options.ACTIVE_TAB_KEY) || null,
    };
  },
  computed: {
    currentTabComponent() {
      // TODO: To replace placeholder strings with actual components
      switch (this.activeTab) {
        case 'chat':
          return {
            title: __('GitLab Duo Chat'),
            component: __('Chat content placeholder'),
          };
        case 'suggestions':
          return {
            title: __('Suggestions'),
            component: __('Suggestions content placeholder'),
          };
        case 'sessions':
          return {
            title: __('Sessions'),
            component: __('Sessions content placeholder'),
          };
        default:
          return null;
      }
    },
  },
  methods: {
    toggleAIPanel(val) {
      this.isExpanded = val;
      if (!val) this.activeTab = null;
    },
    handleTabToggle(tab) {
      if (tab === this.activeTab) {
        // Collapse and clear active tab
        this.toggleAIPanel(false);
        this.activeTab = null;
        localStorage.removeItem(this.$options.ACTIVE_TAB_KEY);
        return;
      }
      this.activeTab = tab;
      localStorage.setItem(this.$options.ACTIVE_TAB_KEY, tab);
      if (!this.isExpanded) {
        this.toggleAIPanel(true);
      }
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-h-full gl-gap-3">
    <local-storage-sync
      :value="isExpanded"
      :storage-key="$options.PANEL_EXPANDED_STORAGE_KEY"
      @input="toggleAIPanel($event)"
    />
    <ai-content-container
      v-if="activeTab"
      :active-tab="currentTabComponent"
      :is-expanded="isExpanded"
      @closePanel="toggleAIPanel"
    />
    <navigation-rail
      :is-expanded="isExpanded"
      :active-tab="activeTab"
      @handleTabToggle="handleTabToggle"
    />
  </div>
</template>

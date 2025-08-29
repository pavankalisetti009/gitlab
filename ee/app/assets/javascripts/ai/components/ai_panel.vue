<script>
import { __ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import ChatPanel from './chat_panel.vue';
import NavigationRail from './navigation_rail.vue';

export default {
  PANEL_EXPANDED_STORAGE_KEY: 'ai-panel-expanded',
  components: {
    ChatPanel,
    NavigationRail,
    LocalStorageSync,
  },
  data() {
    return {
      isExpanded: true,
    };
  },
  computed: {
    panelTitle() {
      // TODO: Set up dynamic titles for the panel based on the chosen mode
      return __('GitLab Duo Chat');
    },
  },
  methods: {
    toggleAIPanel(val) {
      this.isExpanded = val;
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
    <chat-panel :title="panelTitle" :is-expanded="isExpanded" @closePanel="toggleAIPanel" />
    <navigation-rail :is-expanded="isExpanded" @toggleAIPanel="toggleAIPanel" />
  </div>
</template>

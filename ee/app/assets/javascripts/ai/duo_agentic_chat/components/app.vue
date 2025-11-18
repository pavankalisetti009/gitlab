<script>
import { DuoLayout, SideRail } from '@gitlab/duo-ui';
import { duoChatGlobalState } from '~/super_sidebar/constants';

import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __ } from '~/locale';
import { WIDTH_OFFSET } from '../../tanuki_bot/constants';

export default {
  name: 'DuoAgenticLayoutApp',
  components: {
    DuoLayout,
    SideRail,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    namespaceId: {
      type: String,
      required: false,
      default: null,
    },
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    metadata: {
      type: String,
      required: false,
      default: null,
    },
    userModelSelectionEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      duoChatGlobalState,
      width: 550,
      height: window.innerHeight,
      minWidth: 550,
      minHeight: 400,
      // Explicitly initializing the props as null to ensure Vue makes it reactive.
      left: null,
      top: null,
      maxHeight: null,
      maxWidth: null,
    };
  },
  computed: {
    baseProps() {
      return {
        projectId: this.projectId,
        namespaceId: this.namespaceId,
        resourceId: this.resourceId,
        metadata: this.metadata,
        rootNamespaceId: this.rootNamespaceId,
        userModelSelectionEnabled: this.userModelSelectionEnabled,
      };
    },
    dimensions() {
      return {
        width: this.width,
        height: this.height,
        top: this.top,
        maxHeight: this.maxHeight,
        maxWidth: this.maxWidth,
        minWidth: this.minWidth,
        minHeight: this.minHeight,
        left: this.left,
      };
    },
    siderail() {
      return {
        current: { render: true, avatar: 'GitLab Duo Agentic Chat', title: __('Current Chat') },
        new: { render: true, icon: 'plus', title: __('New Chat') },
        history: { render: true, icon: 'history', title: __('History') },
        sessions: {
          render: true,
          icon: 'session-ai',
          dividerBefore: true,
          title: __('Sessions'),
          classes: 'gl-p-3',
        },
      };
    },
  },
  mounted() {
    this.setDimensions();
    window.addEventListener('resize', this.onWindowResize);
    if (this.$route?.path !== '/current') {
      this.$router.push('/current');
    }
  },
  beforeDestroy() {
    // Remove the event listener when the component is destroyed
    window.removeEventListener('resize', this.onWindowResize);
  },
  methods: {
    setDimensions() {
      this.updateDimensions();
    },
    updateDimensions(width, height) {
      this.maxWidth = window.innerWidth - WIDTH_OFFSET;
      this.maxHeight = window.innerHeight;

      this.width = Math.min(width || this.width, this.maxWidth);
      this.height = Math.min(height || this.height, this.maxHeight);
      this.top = window.innerHeight - this.height;
      this.left = window.innerWidth - this.width;
    },
    onChatResize(e) {
      this.updateDimensions(e.width, e.height);
    },
    onWindowResize() {
      this.updateDimensions();
    },
    onClick(route) {
      const targetPath = `/${route}`;
      if (this.$route?.path !== targetPath) {
        this.$router.push(targetPath);
      }
      this.$root.$emit('bv::hide::tooltip');
    },
  },
};
</script>

<template>
  <div v-if="duoChatGlobalState.isAgenticChatShown">
    <duo-layout
      :dimensions="dimensions"
      :should-render-resizable="true"
      class="duo-chat duo-chat-layout !gl-left-auto gl-right-0"
    >
      <template #siderail>
        <side-rail :buttons="siderail" @click="onClick" />
      </template>
      <template #mainview>
        <router-view
          v-bind="baseProps"
          class="gl-grow gl-overflow-auto"
          :class="siderail.classes"
          @chat-resize="onChatResize"
        />
      </template>
    </duo-layout>
  </div>
</template>

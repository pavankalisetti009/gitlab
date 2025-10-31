<script>
import { DuoLayout, SideRail } from '@gitlab/duo-ui';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __ } from '~/locale';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import { WIDTH_OFFSET } from '../constants';

export default {
  name: 'DuoAgenticLayoutApp',
  components: {
    DuoLayout,
    SideRail,
    DuoChatCallout,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    userId: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    chatTitle: {
      type: String,
      required: false,
      default: null,
    },
    agenticAvailable: {
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
        userId: this.userId,
        resourceId: this.resourceId,
        projectId: this.projectId,
        rootNamespaceId: this.rootNamespaceId,
        chatTitle: this.chatTitle,
        agenticAvailable: this.agenticAvailable,
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
        new: { render: true, icon: 'plus', title: __('New Chat') },
        history: { render: true, icon: 'history', title: __('History') },
      };
    },
  },
  mounted() {
    this.setDimensions();
    window.addEventListener('resize', this.onWindowResize);
    this.$router.push('/new');
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
      this.$router.push(`/${route}`);
      this.$root.$emit('bv::hide::tooltip');
    },
  },
};
</script>

<template>
  <div>
    <div v-if="duoChatGlobalState.isShown">
      <duo-layout
        :dimensions="dimensions"
        :should-render-resizable="true"
        class="duo-chat duo-chat-layout !gl-left-auto gl-right-0"
      >
        <template #siderail>
          <side-rail :buttons="siderail" class="gl-px-4" @click="onClick" />
        </template>
        <template #mainview>
          <router-view v-bind="baseProps" @chat-resize="onChatResize" />
        </template>
      </duo-layout>
    </div>
    <duo-chat-callout />
  </div>
</template>

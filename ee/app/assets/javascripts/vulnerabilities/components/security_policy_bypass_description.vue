<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    TimeAgoTooltip,
  },
  directives: {
    SafeHtml,
  },
  props: {
    bypass: {
      type: Object,
      required: true,
    },
  },
  computed: {
    bypassReasons() {
      return Array.isArray(this.bypass.dismissalTypes) ? this.bypass.dismissalTypes.join(', ') : '';
    },
    bypassReasonsText() {
      return sprintf(s__('VulnerabilityManagement|Reason category: %{reasons}'), {
        reasons: this.bypassReasons,
      });
    },
    bypassMRText() {
      return s__('VulnerabilityManagement|Bypassed by %{user} in merge request %{mr}');
    },
    comment() {
      return this.bypass.comment;
    },
    commentText() {
      return sprintf(s__('VulnerabilityManagement|Reason detail: %{comment}'), {
        comment: this.comment,
      });
    },
    showUserAndMR() {
      const { mergeRequestPath, mergeRequestReference, userName, userPath } = this.bypass;
      return mergeRequestPath && mergeRequestReference && userName && userPath;
    },
    statusText() {
      return s__('VulnerabilityManagement|%{statusStart}Bypassed%{statusEnd} · %{timeago}');
    },
    time() {
      return this.bypass.createdAt;
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mt-6">
      <div
        class="gl-float-left !gl-m-0 -gl-mt-1 gl-ml-2 gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-bg-strong gl-text-subtle"
      >
        <gl-icon name="warning" class="circle-icon-container" variant="subtle" />
      </div>
      <div class="gl-ml-5">
        <gl-sprintf v-if="time" :message="statusText">
          <template #status="{ content }">
            <span class="gl-ml-5 gl-font-bold" data-testid="status">{{ content }}</span>
          </template>
          <template #timeago>
            <time-ago-tooltip ref="timeAgo" :time="time" />
          </template>
        </gl-sprintf>
        <ul class="gl-ml-5">
          <li>{{ s__('SecurityOrchestration|Security policy violated') }}</li>
          <li v-if="bypassReasons">{{ bypassReasonsText }}</li>
          <li v-if="comment" v-safe-html="commentText"></li>
          <li v-if="showUserAndMR">
            <gl-sprintf :message="bypassMRText">
              <template #user>
                <gl-link target="_blank" :href="bypass.userPath">{{ bypass.userName }}</gl-link>
              </template>
              <template #mr>
                <gl-link target="_blank" :href="bypass.mergeRequestPath">{{
                  bypass.mergeRequestReference
                }}</gl-link>
              </template>
            </gl-sprintf>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

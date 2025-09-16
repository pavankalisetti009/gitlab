<script>
import { GlSprintf, GlAlert, GlButton } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import { s__ } from '~/locale';
import { getCookie, removeCookie, parseBoolean } from '~/lib/utils/common_utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import { InternalEvents } from '~/tracking';
import { ACTION_LABELS, INVITE_MODAL_OPEN_COOKIE } from '../constants';
import LearnGitlabSectionCard from './learn_gitlab_section_card.vue';

const trackingMixin = InternalEvents.mixin();

export default {
  components: {
    GlSprintf,
    GlAlert,
    GlButton,
    LearnGitlabSectionCard,
  },
  mixins: [trackingMixin],
  i18n: {
    title: s__('LearnGitLab|Learn GitLab'),
    description: s__('LearnGitLab|Follow these steps to get familiar with the GitLab workflow.'),
    percentageCompleted: s__(`LearnGitLab|%{percentage}%{percentSymbol} completed`),
    successfulInvitations: s__(
      "LearnGitLab|Your team is growing! You've successfully invited new team members to the %{projectName} project.",
    ),
    addCodeBlockTitle: s__('LearnGitLab|Get started'),
    buildBlockTitle: s__('LearnGitLab|Next steps'),
    endTutorialButtonLabel: s__('LearnGitlab|End tutorial'),
  },
  props: {
    actions: {
      required: true,
      type: Object,
    },
    sections: {
      required: true,
      type: Array,
    },
    project: {
      required: true,
      type: Object,
    },
    learnGitlabEndPath: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      showSuccessfulInvitationsAlert: false,
      disableEndTutorialButton: false,
      actionsData: this.actions,
    };
  },
  computed: {
    firstBlockSections() {
      return Object.keys(this.sections[0]);
    },
    secondBlockSections() {
      return Object.keys(this.sections[1]);
    },
    maxValue() {
      return Object.keys(this.actionsData).length;
    },
    progressValue() {
      return Object.values(this.actionsData).filter((a) => a.completed).length;
    },
    progressPercentage() {
      return Math.round((this.progressValue / this.maxValue) * 100);
    },
  },
  mounted() {
    if (this.getCookieForInviteMembers()) {
      this.openInviteMembersModal('celebrate', ON_CELEBRATION_TRACK_LABEL);

      this.hideDuoChatPromoCalloutPopover();
    }

    eventHub.$on('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  beforeDestroy() {
    eventHub.$off('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);

    if (this.observer) {
      this.observer.disconnect();
    }
  },
  methods: {
    getCookieForInviteMembers() {
      const value = parseBoolean(getCookie(INVITE_MODAL_OPEN_COOKIE));

      removeCookie(INVITE_MODAL_OPEN_COOKIE);

      return value;
    },
    openInviteMembersModal(mode, source) {
      eventHub.$emit('openModal', { mode, source });
    },
    hideDuoChatPromoCalloutPopover() {
      this.observer = new MutationObserver(() => {
        const popover = document.querySelector('.js-duo-chat-callout-popover');
        if (popover) {
          popover.style.display = 'none';

          if (this.observer) {
            this.observer.disconnect();
            this.observer = null;
          }
        }
      });

      this.observer.observe(document.body, {
        childList: true,
      });
    },
    handleShowSuccessfulInvitationsAlert() {
      this.showSuccessfulInvitationsAlert = true;
      this.markActionAsCompleted('userAdded');
    },
    actionsFor(section) {
      const actions = Object.fromEntries(
        Object.entries(this.actionsData).filter(
          ([action]) => ACTION_LABELS[action].section === section,
        ),
      );
      return actions;
    },
    svgFor(index, section) {
      return this.sections[index][section].svg;
    },
    markActionAsCompleted(completedAction) {
      Object.keys(this.actionsData).forEach((action) => {
        if (action === completedAction) {
          this.actionsData[action].completed = true;
        }
      });
    },
    handleEndTutorialClick() {
      this.disableEndTutorialButton = true;

      this.trackEvent('click_end_tutorial_button', {
        label: 'learn_gitlab',
        property: 'progress_percentage_on_end',
        value: this.progressPercentage,
      });

      visitUrl(this.learnGitlabEndPath);
    },
  },
};
</script>
<template>
  <div data-testid="learn-gitlab-page">
    <gl-alert
      v-if="showSuccessfulInvitationsAlert"
      variant="success"
      class="gl-mt-5"
      @dismiss="showSuccessfulInvitationsAlert = false"
    >
      <gl-sprintf :message="$options.i18n.successfulInvitations">
        <template #projectName>
          <strong>{{ project.name }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>
    <div class="gl-flex gl-flex-col gl-items-center gl-justify-between sm:gl-flex-row">
      <div class="gl-self-start">
        <h1 class="gl-text-size-h1">{{ $options.i18n.title }}</h1>
        <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.description }}</p>
      </div>

      <div class="gl-mt-6 gl-self-start">
        <gl-button
          :disabled="disableEndTutorialButton"
          data-testid="end-tutorial-button"
          @click="handleEndTutorialClick"
        >
          {{ $options.i18n.endTutorialButtonLabel }}
        </gl-button>
      </div>
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-text-size-h2 gl-font-bold">
        {{ $options.i18n.addCodeBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in firstBlockSections"
        :key="section"
        class="col-sm-12 col-mb-6 col-lg-4 gl-mt-5"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(0, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-text-size-h2 gl-font-bold">
        {{ $options.i18n.buildBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in secondBlockSections"
        :key="section"
        class="col-sm-12 col-mb-6 col-lg-4 gl-mt-5"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(1, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>
  </div>
</template>

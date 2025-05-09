<script>
import { GlProgressBar, GlCard, GlSprintf, GlAlert } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import eventHubNav from '~/super_sidebar/event_hub';
import { INVITE_URL_TYPE } from 'ee/pages/projects/get_started/constants';
import SectionHeader from './section_header.vue';
import SectionBody from './section_body.vue';

export default {
  name: 'GetStarted',
  components: {
    GlProgressBar,
    GlCard,
    GlSprintf,
    GlAlert,
    SectionBody,
    SectionHeader,
  },
  props: {
    sections: {
      type: Array,
      required: true,
    },
    projectName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      localSections: this.sections,
      showSuccessfulInvitationsAlert: false,
      expandedIndex: 0,
      totalActions: 0,
      completedActions: 0,
    };
  },
  computed: {
    isExpanded() {
      return (index) => this.expandedIndex === index;
    },
    completionPercentage() {
      return Math.round((this.completedActions / this.totalActions) * 100);
    },
  },
  created() {
    this.calculateActionCounts();
  },
  mounted() {
    eventHub.$on('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  beforeDestroy() {
    eventHub.$off('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  methods: {
    handleShowSuccessfulInvitationsAlert() {
      this.showSuccessfulInvitationsAlert = true;
      this.markInviteAsCompleted();
    },
    dismissAlert() {
      this.showSuccessfulInvitationsAlert = false;
    },
    markInviteAsCompleted() {
      this.localSections.some((section) => {
        if (!section.actions) return false;

        const actionToUpdate = section.actions.find((action) => action.urlType === INVITE_URL_TYPE);

        if (!actionToUpdate) return false;

        actionToUpdate.completed = true;
        return true; // This will break the loop
      });

      this.calculateActionCounts();
      this.modifySidebarPercentage();
    },
    modifySidebarPercentage() {
      eventHubNav.$emit('updatePillValue', {
        value: `${this.completionPercentage}%`,
        itemId: 'get_started',
      });
    },
    toggleExpand(index) {
      this.expandedIndex = this.expandedIndex === index ? null : index;
    },
    calculateActionCounts() {
      this.totalActions = 0;
      this.completedActions = 0;

      this.localSections.forEach((section) => {
        // Count regular actions
        if (section.actions) {
          this.totalActions += section.actions.length;
          this.completedActions += section.actions.filter((action) => action.completed).length;
        }

        // Count trial actions
        if (section.trialActions) {
          this.totalActions += section.trialActions.length;
          this.completedActions += section.trialActions.filter((action) => action.completed).length;
        }
      });
    },
  },
};
</script>

<template>
  <div class="row" data-testid="get-started-page">
    <div
      class="col-md-9 gl-flex gl-flex-col gl-gap-4 md:gl-pr-6"
      data-testid="get-started-sections"
    >
      <gl-alert
        v-if="showSuccessfulInvitationsAlert"
        variant="success"
        class="gl-mt-5"
        @dismiss="dismissAlert"
      >
        <gl-sprintf
          :message="
            s__(
              'LearnGitLab|Your team is growing! You\'ve successfully invited new team members to the %{projectName} project.',
            )
          "
        >
          <template #projectName>
            <strong>{{ projectName }}</strong>
          </template>
        </gl-sprintf>
      </gl-alert>

      <header>
        <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|Quick start') }}</h2>
        <p class="gl-mb-0 gl-text-subtle">
          {{ s__('LearnGitLab|Follow these steps to get familiar with the GitLab workflow.') }}
        </p>
      </header>

      <gl-progress-bar :value="completionPercentage" data-testid="progress-bar" />

      <gl-card
        v-for="(section, index) in localSections"
        :key="index"
        body-class="gl-py-0"
        :header-class="isExpanded(index) ? '' : 'gl-border-b-0'"
      >
        <template #header>
          <section-header
            :section="section"
            :is-expanded="isExpanded(index)"
            :section-index="index"
            @toggle-expand="toggleExpand(index)"
          />
        </template>
        <section-body :section="section" :is-expanded="isExpanded(index)" />
      </gl-card>
    </div>

    <div class="col-md-3 md:gl-pl-6">
      <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|GitLab University') }}</h2>
    </div>
  </div>
</template>

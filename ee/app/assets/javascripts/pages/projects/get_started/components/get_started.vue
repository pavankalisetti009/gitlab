<script>
import { GlButton, GlCard, GlSprintf, GlAlert } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import { visitUrl } from '~/lib/utils/url_utility';
import SectionHeader from './section_header.vue';
import SectionBody from './section_body.vue';
import DuoExtensions from './duo_extensions.vue';
import RightSidebar from './right_sidebar.vue';
import GetFamiliar from './get_familiar.vue';

export default {
  name: 'GetStarted',
  components: {
    GlButton,
    GlCard,
    GlSprintf,
    GlAlert,
    SectionBody,
    SectionHeader,
    DuoExtensions,
    RightSidebar,
    GetFamiliar,
  },
  inject: ['projectName'],
  props: {
    sections: {
      type: Array,
      required: true,
    },
    tutorialEndPath: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      localSections: this.sections,
      showSuccessfulInvitationsAlert: false,
      expandedIndex: 0,
      disableEndTutorialButton: false,
    };
  },
  computed: {
    isExpanded() {
      return (index) => this.expandedIndex === index;
    },
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
    },
    dismissAlert() {
      this.showSuccessfulInvitationsAlert = false;
    },
    toggleExpand(index) {
      this.expandedIndex = this.expandedIndex === index ? null : index;
    },
    handleEndTutorialClick() {
      this.disableEndTutorialButton = true;

      visitUrl(this.tutorialEndPath);
    },
  },
};
</script>

<template>
  <div class="row" data-testid="get-started-page">
    <div
      class="col-md-9 gl-flex gl-flex-col gl-gap-4 md:gl-pr-9"
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
        <div class="gl-flex gl-items-baseline gl-justify-between">
          <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|Quick start') }}</h2>
          <gl-button
            :disabled="disableEndTutorialButton"
            category="tertiary"
            data-testid="end-tutorial-button"
            @click="handleEndTutorialClick"
          >
            {{ s__('LearnGitLab|End tutorial') }}
          </gl-button>
        </div>
        <p class="gl-mb-0 gl-text-subtle">
          {{ s__('LearnGitLab|Follow these steps to get familiar with the GitLab workflow.') }}
        </p>
      </header>

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
      <duo-extensions />
      <get-familiar />
    </div>

    <div class="col-md-3 gl-w-full md:gl-pl-0">
      <right-sidebar />
    </div>
  </div>
</template>

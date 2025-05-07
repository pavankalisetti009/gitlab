<script>
import { GlProgressBar, GlCard } from '@gitlab/ui';
import SectionHeader from './section_header.vue';
import SectionBody from './section_body.vue';

export default {
  name: 'GetStarted',
  components: {
    GlProgressBar,
    GlCard,
    SectionBody,
    SectionHeader,
  },
  props: {
    sections: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
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
  methods: {
    toggleExpand(index) {
      this.expandedIndex = this.expandedIndex === index ? null : index;
    },
    calculateActionCounts() {
      this.totalActions = 0;
      this.completedActions = 0;

      this.sections.forEach((section) => {
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
      <header>
        <h2 class="gl-text-size-h2">{{ s__('GetStarted|Quick start') }}</h2>
        <p class="gl-mb-0 gl-text-subtle">
          {{ s__('GetStarted|Follow these steps to get familiar with the GitLab workflow.') }}
        </p>
      </header>

      <gl-progress-bar :value="completionPercentage" />

      <gl-card
        v-for="(section, index) in sections"
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
      <h2 class="gl-text-size-h2">{{ s__('GetStarted|GitLab University') }}</h2>
    </div>
  </div>
</template>

<script>
import { GlSprintf, GlAlert, GlLink } from '@gitlab/ui';
import Tracking from '~/tracking';
import {
  FEEDBACK_ISSUE_URL,
  STANDARDS_ADHERENCE_DOCS_URL,
} from 'ee/compliance_dashboard/constants';
import { s__ } from '~/locale';
import ComplianceStandardsAdherenceTable from './standards_adherence_table.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTable,
    GlAlert,
    GlLink,
    GlSprintf,
  },
  mixins: [Tracking.mixin()],
  inject: ['activeComplianceFrameworks', 'adherenceV2Enabled'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      showBanner: this.adherenceV2Enabled,
    };
  },
  mounted() {
    this.track('visit_standards_adherence', {
      property: this.activeComplianceFrameworks ? 'with_active_compliance_frameworks' : '',
    });
  },
  i18n: {
    feedbackTitle: s__(
      "AdherenceReport|We've updated the Adherence Report with new features to enhance your compliance workflow.",
    ),
    learnMoreDocsText: s__(
      'AdherenceReport|Learn more about the changes in our %{linkStart}documentation%{linkEnd}.',
    ),
    feedbackText: s__(
      'AdherenceReport|Have questions or thoughts on the new improvements we made? %{linkStart}Please provide feedback on your experience%{linkEnd}.',
    ),
  },
  FEEDBACK_ISSUE_URL,
  STANDARDS_ADHERENCE_DOCS_URL,
};
</script>

<template>
  <div>
    <gl-alert v-if="showBanner" variant="info" dismissible @dismiss="showBanner = false">
      <div>
        {{ $options.i18n.feedbackTitle }}
        <gl-sprintf :message="$options.i18n.learnMoreDocsText">
          <template #link="{ content }">
            <gl-link :href="$options.STANDARDS_ADHERENCE_DOCS_URL" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
        <gl-sprintf :message="$options.i18n.feedbackText">
          <template #link="{ content }">
            <gl-link :href="$options.FEEDBACK_ISSUE_URL" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
    </gl-alert>
    <compliance-standards-adherence-table :group-path="groupPath" :project-path="projectPath" />
  </div>
</template>

<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { helpPagePath } from '~/helpers/help_page_helper';
import GitlabExperiment from '~/experimentation/components/gitlab_experiment.vue';
import RootCauseAnalysisButton from 'ee_else_ce/ci/job_details/components/root_cause_analysis_button.vue';
import hotspotImageUrl from 'ee_images/illustrations/hotspot.gif';
import Tracking from '~/tracking';

export default {
  name: 'RootCauseAnalysisHotspotExperiment',
  components: {
    GlPopover,
    GlLink,
    RootCauseAnalysisButton,
    GitlabExperiment,
  },
  mixins: [Tracking.mixin({ experiment: 'root_cause_analysis_hotspot' })],
  helpPageLink: helpPagePath('user/gitlab_duo_chat/examples', {
    anchor: 'troubleshoot-failed-cicd-jobs-with-root-cause-analysis',
  }),
  props: {
    jobId: {
      type: Number,
      required: false,
      default: null,
    },
    jobGid: {
      type: String,
      required: false,
      default: '',
    },
    jobStatusGroup: {
      type: String,
      required: true,
    },
    canTroubleshootJob: {
      type: Boolean,
      required: true,
    },
    isBuild: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      showPopover: false,
      hotspotId: null,
    };
  },
  mounted() {
    this.hotspotId = ['job', this.jobId || uniqueId(), 'hotspot'].join('-');
    this.track('render');
  },
  methods: {
    onDuoCalled() {
      this.track('click_troubleshoot');

      if (this.showPopover) {
        this.showPopover = false;
      }
    },
    onHotspotClick() {
      this.track('click_hotspot');

      this.showPopover = !this.showPopover;
    },
    dismissPopover() {
      this.track('dismiss_popover');
    },
  },
  hotspotImageUrl,
};
</script>
<template>
  <gitlab-experiment name="root_cause_analysis_hotspot">
    <template #control>
      <root-cause-analysis-button
        ref="rootCauseButton"
        :job-id="jobId"
        :job-gid="jobGid"
        :job-status-group="jobStatusGroup"
        :can-troubleshoot-job="canTroubleshootJob"
        :is-build="isBuild"
        @duo-called="onDuoCalled"
      />
    </template>
    <template #candidate>
      <div class="gl-mr-2 gl-flex gl-items-center">
        <root-cause-analysis-button
          ref="rootCauseButtonCandidate"
          :job-id="jobId"
          :job-gid="jobGid"
          :job-status-group="jobStatusGroup"
          :can-troubleshoot-job="canTroubleshootJob"
          :is-build="isBuild"
          @duo-called="onDuoCalled"
        />
        <button
          :id="hotspotId"
          data-testid="hotspot"
          class="gl-ml-3 gl-flex gl-items-center gl-rounded-full gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
          @click.stop="onHotspotClick"
        >
          <img
            :src="$options.hotspotImageUrl"
            :alt="__('Hotspot indicator')"
            class="gl-h-4 gl-w-4"
          />
        </button>
        <gl-popover
          :target="hotspotId"
          :show="showPopover"
          triggers="focus"
          :aria-label="__(`Close`)"
          show-close-button
          @close-button-clicked="dismissPopover"
          @hidden="showPopover = false"
        >
          <template #title>
            <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
              <strong>{{ __('Root Cause Analysis') }}</strong>
            </div>
          </template>
          <p>
            {{ __('Quickly identify the root cause of an incident using AI-assisted analysis.') }}
            <gl-link
              :href="$options.helpPageLink"
              target="_blank"
              rel="noopener noreferrer"
              tabindex="0"
              :aria-label="__('Learn more about Root Cause Analysis in new tab')"
            >
              {{ __('Learn more about Root Cause Analysis') }}
            </gl-link>
          </p>
        </gl-popover>
      </div>
    </template>
  </gitlab-experiment>
</template>

<script>
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/branch_selection.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import { getHostname } from '../../utils';
import { CADENCE_OPTIONS, updateScheduleCadence } from './utils';

export default {
  name: 'ScheduleForm',
  CADENCE_OPTIONS,
  i18n: {
    cadence: __('Cadence'),
    details: s__(
      'SecurityOrchestration|at the following times: %{cadenceSelector}, start at %{start}, run for: %{duration}, and timezone is %{timezoneSelector}',
    ),
    message: s__('SecurityOrchestration|Schedule to run for %{branchSelector}'),
    timezoneLabel: s__('ScanExecutionPolicy|on %{hostname}'),
    timezonePlaceholder: s__('ScanExecutionPolicy|Select timezone'),
  },
  components: {
    BranchSelection,
    GlCollapsibleListbox,
    GlSprintf,
    TimezoneDropdown,
  },
  inject: ['timezones'],
  props: {
    schedule: {
      type: Object,
      required: true,
    },
  },
  computed: {
    branchInfo() {
      return {
        branch_type: this.schedule?.branch_type,
        branches: this.schedule?.branches,
      };
    },
    timezoneTooltipText() {
      return sprintf(this.$options.i18n.timezoneLabel, { hostname: getHostname() });
    },
  },
  methods: {
    updateBranchType({ branch_type, branches }) {
      const {
        branch_type: oldBranchType,
        branches: oldBranches,
        ...updatedSchedule
      } = this.schedule;

      this.$emit('changed', {
        ...updatedSchedule,
        ...(branch_type ? { branch_type } : { branches }), // eslint-disable-line camelcase
      });
    },
    updateCadence(value) {
      const updatedSchedule = updateScheduleCadence({ schedule: this.schedule, cadence: value });
      this.$emit('changed', updatedSchedule);
    },
    handleTimeZoneInput({ identifier }) {
      this.$emit('changed', { ...this.schedule, timezone: identifier });
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-3 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.message">
        <template #branchSelector>
          <branch-selection :init-rule="branchInfo" @set-branch-type="updateBranchType" />
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.details">
        <template #cadenceSelector>
          <gl-collapsible-listbox
            :aria-label="$options.i18n.cadence"
            :items="$options.CADENCE_OPTIONS"
            :selected="schedule.type"
            @select="updateCadence"
          />
        </template>

        <template #start> </template>

        <template #duration> </template>

        <template #timezoneSelector>
          <timezone-dropdown
            :aria-label="$options.i18n.timezonePlaceholder"
            class="gl-max-w-26"
            :header-text="$options.i18n.timezonePlaceholder"
            :timezone-data="timezones"
            :title="timezoneTooltipText"
            :value="schedule.timezone"
            @input="handleTimeZoneInput"
          />
        </template>
      </gl-sprintf>
    </div>
  </div>
</template>

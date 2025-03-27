<script>
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { n__, s__, __, sprintf } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/branch_selection.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import { getHostname } from '../../utils';
import {
  CADENCE_OPTIONS,
  HOUR_MINUTE_LIST,
  WEEKDAY_OPTIONS,
  isCadenceWeekly,
  isCadenceMonthly,
  updateScheduleCadence,
  getMonthlyDayOptions,
} from './utils';

export default {
  name: 'ScheduleForm',
  CADENCE_OPTIONS,
  HOUR_MINUTE_LIST,
  WEEKDAY_OPTIONS,
  i18n: {
    cadence: __('Cadence'),
    cadenceDetail: s__('SecurityOrchestration|on every'),
    details: s__(
      'SecurityOrchestration|at the following times: %{cadenceSelector}, start at %{start}, run for: %{duration}, and timezone is %{timezoneSelector}',
    ),
    message: s__('SecurityOrchestration|Schedule to run for %{branchSelector}'),
    time: __('Time'),
    timezoneLabel: s__('ScanExecutionPolicy|on %{hostname}'),
    timezonePlaceholder: s__('ScanExecutionPolicy|Select timezone'),
    weekly: __('Weekly'),
    weekdayDropdownPlaceholder: __('Select a day'),
    monthly: __('Monthly'),
    monthlyDaysLabel: s__('SecurityOrchestration|Days of month'),
    monthlyDaysPlaceholder: s__('SecurityOrchestration|Select days'),
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
      const { branch_type, branches, type } = this.schedule;
      return {
        type,
        ...(branch_type ? { branch_type } : {}), // eslint-disable-line camelcase
        ...(branches ? { branches } : {}),
      };
    },
    cadence() {
      return this.schedule.type;
    },
    showMonthlyDropdown() {
      return isCadenceMonthly(this.cadence);
    },
    showWeekdayDropdown() {
      return isCadenceWeekly(this.cadence);
    },
    timezoneTooltipText() {
      return sprintf(this.$options.i18n.timezoneLabel, { hostname: getHostname() });
    },
    weekdayToggleText() {
      return getSelectedOptionsText({
        options: this.$options.WEEKDAY_OPTIONS,
        selected: this.schedule.days || [],
        placeholder: this.$options.i18n.weekdayDropdownPlaceholder,
        maxOptionsShown: 2,
      });
    },
    monthlyDayOptions() {
      return getMonthlyDayOptions();
    },
    selectedMonthlyDays() {
      return this.schedule.days_of_month || [];
    },
    monthlyDaysToggleText() {
      return getSelectedOptionsText({
        options: this.monthlyDayOptions,
        selected: this.selectedMonthlyDays,
        placeholder: this.$options.i18n.monthlyDaysPlaceholder,
        maxOptionsShown: 2,
      });
    },
    monthlyDaysMessage() {
      return n__('day of the month', 'days of the month', this.selectedMonthlyDays.length);
    },
  },
  methods: {
    updateBranchConfig({ branch_type, branches }) {
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
    updatePolicy(key, value) {
      this.$emit('changed', { ...this.schedule, [key]: value });
    },
    handleMonthlyDaysInput(selectedDays) {
      this.updatePolicy('days_of_month', selectedDays);
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-3 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.message">
        <template #branchSelector>
          <branch-selection
            :init-rule="branchInfo"
            @changed="updateBranchConfig"
            @set-branch-type="updateBranchConfig"
          />
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.details">
        <template #cadenceSelector>
          <gl-collapsible-listbox
            :aria-label="$options.i18n.cadence"
            :items="$options.CADENCE_OPTIONS"
            :selected="cadence"
            @select="updateCadence"
          />

          <template v-if="showWeekdayDropdown">
            {{ $options.i18n.cadenceDetail }}
            <gl-collapsible-listbox
              multiple
              data-testid="weekday-dropdown"
              :aria-label="$options.i18n.weekly"
              :items="$options.WEEKDAY_OPTIONS"
              :selected="schedule.days"
              :toggle-text="weekdayToggleText"
              @select="updatePolicy('days', $event)"
            />
          </template>

          <template v-else-if="showMonthlyDropdown">
            {{ $options.i18n.cadenceDetail }}
            <div class="gl-flex gl-items-center">
              <gl-collapsible-listbox
                class="gl-mr-3"
                multiple
                data-testid="monthly-days-dropdown"
                :aria-label="$options.i18n.monthlyDaysLabel"
                :items="monthlyDayOptions"
                :selected="selectedMonthlyDays"
                :toggle-text="monthlyDaysToggleText"
                @select="handleMonthlyDaysInput"
              />
              {{ monthlyDaysMessage }}
            </div>
          </template>
        </template>

        <template #start>
          <gl-collapsible-listbox
            data-testid="time-dropdown"
            :aria-label="$options.i18n.time"
            :items="$options.HOUR_MINUTE_LIST"
            :selected="schedule.start_time"
            @select="updatePolicy('start_time', $event)"
          />
        </template>

        <template #duration> </template>

        <template #timezoneSelector>
          <timezone-dropdown
            :aria-label="$options.i18n.timezonePlaceholder"
            class="gl-max-w-26"
            :header-text="$options.i18n.timezonePlaceholder"
            :timezone-data="timezones"
            :title="timezoneTooltipText"
            :value="schedule.timezone"
            @input="updatePolicy('timezone', $event.identifier)"
          />
        </template>
      </gl-sprintf>
    </div>
  </div>
</template>

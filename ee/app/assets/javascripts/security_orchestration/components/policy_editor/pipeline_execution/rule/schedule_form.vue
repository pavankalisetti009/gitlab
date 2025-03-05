<script>
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { CADENCE_OPTIONS, updateScheduleCadence } from './utils';

export default {
  name: 'ScheduleForm',
  CADENCE_OPTIONS,
  i18n: {
    cadence: __('Cadence'),
    message: s__(
      'SecurityOrchestration|Schedule a pipeline on a %{cadenceSelector} cadence for branches',
    ),
  },
  components: {
    GlCollapsibleListbox,
    GlSprintf,
  },
  props: {
    schedule: {
      type: Object,
      required: true,
    },
  },
  methods: {
    updateCadence(value) {
      const updatedSchedule = updateScheduleCadence({ schedule: this.schedule, cadence: value });
      this.$emit('changed', updatedSchedule);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
    <gl-sprintf :message="$options.i18n.message">
      <template #cadenceSelector>
        <gl-collapsible-listbox
          :aria-label="$options.i18n.cadence"
          :items="$options.CADENCE_OPTIONS"
          :selected="schedule.type"
          @select="updateCadence"
        />
      </template>
    </gl-sprintf>
  </div>
</template>

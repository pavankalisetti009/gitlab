<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters, mapActions } from 'vuex';
import OverviewChart from './overview_chart.vue';
import StageChart from './stage_chart.vue';

export default {
  name: 'DurationChartLoader',
  components: {
    OverviewChart,
    StageChart,
  },
  computed: {
    ...mapState(['selectedStage']),
    ...mapGetters(['isOverviewStageSelected']),
    ...mapState('durationChart', ['isLoading', 'errorMessage']),
    ...mapGetters('durationChart', [
      'durationChartPlottableData',
      'durationOverviewChartPlottableData',
    ]),
  },
  watch: {
    selectedStage() {
      this.fetchDurationData();
    },
  },
  created() {
    this.fetchDurationData();
  },
  methods: {
    ...mapActions('durationChart', ['fetchDurationData']),
  },
};
</script>
<template>
  <overview-chart
    v-if="isOverviewStageSelected"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="durationOverviewChartPlottableData"
  />
  <stage-chart
    v-else
    :stage-title="selectedStage.title"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="durationChartPlottableData"
  />
</template>

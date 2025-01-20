<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters, mapActions } from 'vuex';
import { getDurationOverviewChartData, getDurationChartData } from '../../utils';
import OverviewChart from './overview_chart.vue';
import StageChart from './stage_chart.vue';

export default {
  name: 'DurationChartLoader',
  components: {
    OverviewChart,
    StageChart,
  },
  computed: {
    ...mapState(['selectedStage', 'createdAfter', 'createdBefore']),
    ...mapGetters(['isOverviewStageSelected']),
    ...mapState('durationChart', ['durationData', 'isLoading', 'errorMessage']),
    hasPlottableData() {
      return this.durationData.some(({ data }) => data.length);
    },
    overviewChartPlottableData() {
      return this.hasPlottableData ? getDurationOverviewChartData(this.durationData) : [];
    },
    stageChartPlottableData() {
      const { createdAfter, createdBefore, durationData, selectedStage } = this;
      const stageDurationData = durationData.find((stage) => stage.id === selectedStage.id);

      return stageDurationData?.data?.length
        ? getDurationChartData([stageDurationData], createdAfter, createdBefore)
        : [];
    },
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
    :plottable-data="overviewChartPlottableData"
  />
  <stage-chart
    v-else
    :stage-title="selectedStage.title"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="stageChartPlottableData"
  />
</template>

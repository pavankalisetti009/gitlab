<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { __ } from '~/locale';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { getTypeOfWorkTasksByType } from 'ee/api/analytics_api';
import {
  getTasksByTypeData,
  checkForDataError,
  alertErrorIfStatusNotOk,
  transformRawTasksByTypeData,
} from '../utils';
import TypeOfWorkCharts from './type_of_work_charts.vue';

export default {
  name: 'TypeOfWorkChartsLoader',
  components: {
    ChartSkeletonLoader,
    TypeOfWorkCharts,
  },
  data() {
    return {
      tasksByType: [],
      isLoadingTasksByType: false,
    };
  },
  computed: {
    ...mapState(['namespace', 'createdAfter', 'createdBefore']),
    ...mapState('typeOfWork', ['subject', 'errorMessage', 'isLoading']),
    ...mapGetters(['cycleAnalyticsRequestParams']),
    ...mapGetters('typeOfWork', ['selectedLabelNames']),
    chartData() {
      const { tasksByType, createdAfter, createdBefore } = this;
      return tasksByType.length
        ? getTasksByTypeData({ data: tasksByType, createdAfter, createdBefore })
        : { groupBy: [], data: [] };
    },
    hasError() {
      return this.errorMessage && this.errorMessage !== '';
    },
    tasksByTypeParams() {
      const {
        subject,
        selectedLabelNames,
        cycleAnalyticsRequestParams: {
          project_ids,
          created_after,
          created_before,
          author_username,
          milestone_title,
          assignee_username,
        },
      } = this;
      return {
        project_ids,
        created_after,
        created_before,
        author_username,
        milestone_title,
        assignee_username,
        subject,
        label_names: selectedLabelNames,
      };
    },
  },
  async created() {
    await this.fetchTopRankedGroupLabels();

    if (!this.hasError) {
      this.fetchTasksByType();
    }
  },
  methods: {
    ...mapActions('typeOfWork', ['fetchTopRankedGroupLabels', 'setTasksByTypeFilters']),
    onUpdateFilter(e) {
      this.setTasksByTypeFilters(e);
      this.fetchTasksByType();
    },
    fetchTasksByType() {
      // dont request if we have no labels selected
      if (!this.selectedLabelNames.length) {
        this.tasksByType = [];
        return;
      }

      this.isLoadingTasksByType = true;

      getTypeOfWorkTasksByType(this.namespace.fullPath, this.tasksByTypeParams)
        .then(checkForDataError)
        .then(({ data }) => {
          this.tasksByType = transformRawTasksByTypeData(data);
        })
        .catch((error) => {
          alertErrorIfStatusNotOk({
            error,
            message: __('There was an error fetching data for the tasks by type chart'),
          });
        })
        .finally(() => {
          this.isLoadingTasksByType = false;
        });
    },
  },
};
</script>
<template>
  <div class="js-tasks-by-type-chart">
    <chart-skeleton-loader v-if="isLoading || isLoadingTasksByType" class="gl-my-4 gl-py-4" />
    <type-of-work-charts v-else :chart-data="chartData" @update-filter="onUpdateFilter" />
  </div>
</template>

<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { GlAlert, GlIcon, GlTooltip } from '@gitlab/ui';
import { __ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { getTypeOfWorkTasksByType } from 'ee/api/analytics_api';
import {
  generateFilterTextDescription,
  getTasksByTypeData,
  checkForDataError,
  alertErrorIfStatusNotOk,
  transformRawTasksByTypeData,
} from '../utils';
import { formattedDate } from '../../shared/utils';
import { TASKS_BY_TYPE_SUBJECT_ISSUE, TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS } from '../constants';
import TasksByTypeChart from './tasks_by_type/chart.vue';
import TasksByTypeFilters from './tasks_by_type/filters.vue';
import NoDataAvailableState from './no_data_available_state.vue';

export default {
  name: 'TypeOfWorkCharts',
  components: {
    ChartSkeletonLoader,
    GlAlert,
    GlIcon,
    GlTooltip,
    TasksByTypeChart,
    TasksByTypeFilters,
    NoDataAvailableState,
  },
  directives: {
    SafeHtml,
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
    ...mapGetters(['selectedProjectIds', 'cycleAnalyticsRequestParams']),
    ...mapGetters('typeOfWork', ['selectedLabelNames']),
    chartData() {
      const { tasksByType, createdAfter, createdBefore } = this;
      return tasksByType.length
        ? getTasksByTypeData({ data: tasksByType, createdAfter, createdBefore })
        : { groupBy: [], data: [] };
    },
    hasData() {
      return Boolean(this.chartData?.data.length);
    },
    hasError() {
      return this.errorMessage && this.errorMessage !== '';
    },
    tooltipText() {
      return generateFilterTextDescription({
        groupName: this.namespace.name,
        selectedLabelsCount: this.selectedLabelNames.length,
        selectedProjectsCount: this.selectedProjectIds.length,
        selectedSubjectFilterText: this.selectedSubjectFilterText.toLowerCase(),
        createdAfter: formattedDate(this.createdAfter),
        createdBefore: formattedDate(this.createdBefore),
      });
    },
    selectedSubjectFilter() {
      return this.subject || TASKS_BY_TYPE_SUBJECT_ISSUE;
    },
    selectedSubjectFilterText() {
      const { selectedSubjectFilter } = this;
      return (
        TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[selectedSubjectFilter] ||
        TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[TASKS_BY_TYPE_SUBJECT_ISSUE]
      );
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
    <div v-else>
      <div class="gl-flex gl-justify-between">
        <h4 class="gl-mt-0">
          {{ s__('ValueStreamAnalytics|Tasks by type') }}&nbsp;
          <span ref="tooltipTrigger" data-testid="vsa-task-by-type-description">
            <gl-icon name="information-o" />
          </span>
          <gl-tooltip :target="() => $refs.tooltipTrigger" boundary="viewport" placement="top">
            <span v-safe-html="tooltipText"></span>
          </gl-tooltip>
        </h4>
        <tasks-by-type-filters
          :selected-label-names="selectedLabelNames"
          :subject-filter="selectedSubjectFilter"
          @update-filter="onUpdateFilter"
        />
      </div>
      <tasks-by-type-chart v-if="hasData" :data="chartData.data" :group-by="chartData.groupBy" />
      <gl-alert v-else-if="errorMessage" variant="info" :dismissible="false" class="gl-mt-3">
        {{ errorMessage }}
      </gl-alert>
      <no-data-available-state v-else />
    </div>
  </div>
</template>

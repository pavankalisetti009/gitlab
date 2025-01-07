import { withVuexStore } from 'storybook_addons/vuex_store';
import StageChart from './stage_chart.vue';
import { stageChartData, selectedStage } from './stories_constants';

export default {
  component: StageChart,
  title: 'ee/analytics/cycle_analytics/components/stage_chart',
  decorators: [withVuexStore],
};

const Template = (args, { argTypes, createVuexStore }) => ({
  components: { StageChart },
  props: Object.keys(argTypes),
  template: '<stage-chart v-bind="$props" />',
  store: createVuexStore({
    state: {
      selectedStage,
    },
    modules: {
      durationChart: {
        namespaced: true,
        getters: {
          durationChartPlottableData: () => stageChartData,
        },
        state: {
          isLoading: false,
        },
      },
    },
  }),
});

export const Default = Template.bind({});

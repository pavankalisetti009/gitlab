import { withVuexStore } from 'storybook_addons/vuex_store';
import {
  defaultStageConfig,
  stageEvents,
  valueStream,
  valueStreamStages,
} from './stories_constants';
import ValueStreamForm from './value_stream_form.vue';

export default {
  component: ValueStreamForm,
  title: 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ state = {} } = {}) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { ValueStreamForm },
    provide: {
      vsaPath: '',
      stageEvents,
    },
    props: Object.keys(argTypes),
    template: '<value-stream-form v-bind="$props" />',
    store: createVuexStore({
      state: {
        defaultStageConfig,
        isLoading: false,
        ...state,
      },
    }),
  });
};

export const Default = {
  render: createStoryWithState(),
};

export const EditValueStream = {
  render: createStoryWithState({
    state: {
      stages: valueStreamStages(),
    },
  }),
  args: {
    isEditing: true,
    valueStream,
  },
};

export const EditValueStreamWithCustomStages = {
  render: createStoryWithState({
    state: {
      stages: valueStreamStages({ addCustomStage: true }),
    },
  }),
  args: {
    isEditing: true,
    valueStream,
  },
};

export const EditValueStreamWithHiddenStages = {
  render: createStoryWithState({
    state: {
      stages: valueStreamStages({ addCustomStage: true, hideStages: true }),
    },
  }),
  args: {
    isEditing: true,
    valueStream,
  },
};

export const Loading = {
  render: createStoryWithState({
    state: {
      isLoading: true,
    },
  }),
};

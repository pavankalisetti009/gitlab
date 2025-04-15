import { withVuexStore } from 'storybook_addons/vuex_store';
import { defaultStages, stageEvents, valueStream, valueStreamStages } from './stories_constants';
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
      namespaceFullPath: '',
      valueStream,
      stageEvents,
      defaultStages,
    },
    props: Object.keys(argTypes),
    template: '<value-stream-form v-bind="$props" />',
    store: createVuexStore({
      state: {
        isFetchingGroupStages: false,
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
  },
};

export const Loading = {
  render: createStoryWithState({
    state: {
      isFetchingGroupStages: true,
    },
  }),
};

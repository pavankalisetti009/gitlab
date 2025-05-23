import { mockLabelsResponse } from 'ee_jest/analytics/cycle_analytics/vsa_settings/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import { generateInitialStageData } from '../utils';
import getCustomStageLabels from '../graphql/get_custom_stage_labels.query.graphql';
import {
  defaultStages,
  stageEvents,
  valueStream,
  valueStreamGid,
  valueStreamStages,
} from './stories_constants';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  component: ValueStreamFormContent,
  title: 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content',
};

const generateInitialData = (stages) => ({
  ...valueStream,
  stages: generateInitialStageData(defaultStages, stages),
});

const mockApolloProvider = () =>
  createMockApollo([[getCustomStageLabels, () => Promise.resolve(mockLabelsResponse)]]);

const Template = (args, { argTypes }) => ({
  components: { ValueStreamFormContent },
  apolloProvider: mockApolloProvider(),
  provide: {
    vsaPath: '',
    namespaceFullPath: '',
    groupPath: 'group',
    valueStreamGid: args.valueStreamGid ?? valueStreamGid,
    stageEvents,
    defaultStages,
  },
  props: Object.keys(argTypes),
  template: '<value-stream-form-content v-bind="$props" />',
});

export const NewValueStream = Template.bind({});
NewValueStream.args = { valueStreamGid: '' };

export const EditValueStream = Template.bind({});
EditValueStream.args = {
  initialData: generateInitialData(valueStreamStages()),
};

export const EditValueStreamWithCustomStages = Template.bind({});
EditValueStreamWithCustomStages.args = {
  initialData: generateInitialData(valueStreamStages({ addCustomStage: true })),
};

export const EditValueStreamWithHiddenStages = Template.bind({});
EditValueStreamWithHiddenStages.args = {
  initialData: generateInitialData(valueStreamStages({ addCustomStage: true, hideStages: true })),
};

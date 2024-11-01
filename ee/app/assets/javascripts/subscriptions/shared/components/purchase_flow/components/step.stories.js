import { createMockApolloProvider } from 'ee_jest/subscriptions/shared/components/purchase_flow/spec_helper';
import { STEPS } from 'ee_jest/subscriptions/shared/components/purchase_flow/mock_data';
import Step from './step.vue';

export default {
  component: Step,
  title: 'ee/subscriptions/shared/components/purchase_flow/step',
};

const Template = (_, { argTypes }) => ({
  components: { Step },
  apolloProvider: createMockApolloProvider(STEPS, 1),
  props: Object.keys(argTypes),
  template: '<step v-bind="$props" />',
});

const defaultProps = {
  stepId: 'secondStep',
  title: 'Confirm your address',
  nextStepButtonText: 'To payment',
  isValid: true,
};

export const ActiveStep = Template.bind({});
ActiveStep.args = {
  ...defaultProps,
};

export const FinishedStep = Template.bind({});
FinishedStep.args = {
  ...defaultProps,
  stepId: 'thirdStep',
};

export const StepWithError = Template.bind({});
StepWithError.args = {
  ...defaultProps,
  isValid: false,
  errorMessage: 'Something went wrong with your address',
};

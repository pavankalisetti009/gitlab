import StepHeader from './step_header.vue';

export default {
  component: StepHeader,
  title: 'ee/vue_shared/purchase_flow/step_header',
};

const Template = (_, { argTypes }) => ({
  components: { StepHeader },
  props: Object.keys(argTypes),
  template: '<step-header v-bind="$props" />',
});

const defaultProps = {
  isFinished: false,
  isEditable: false,
  title: 'Next step',
  editButtonText: 'edit',
};

export const Default = Template.bind({});
Default.args = {
  ...defaultProps,
};

export const Finished = Template.bind({});
Finished.args = {
  ...defaultProps,
  isFinished: true,
};

export const Editable = Template.bind({});
Editable.args = {
  ...defaultProps,
  isEditable: true,
};

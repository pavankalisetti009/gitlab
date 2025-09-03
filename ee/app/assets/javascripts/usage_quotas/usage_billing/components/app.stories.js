import UsageBillingApp from './app.vue';

export default {
  component: UsageBillingApp,
  title: 'ee/usage_billing/App',
};

const Template = (args, { argTypes }) => ({
  props: Object.keys(argTypes),
  components: { UsageBillingApp },
  template: '<usage-billing-app v-bind="$props" />',
});

export const Default = Template.bind({});

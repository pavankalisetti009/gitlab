import SecurityListItem from './security_list_item.vue';

const defaultRender = (args) => ({
  components: { SecurityListItem },
  data() {
    return {
      ...args,
    };
  },
  template:
    '<security-list-item :policyName="policyName" :loading="loading" :findings="findings" />',
});

const Template = (args) => defaultRender(args);

export const Default = Template.bind({});
Default.args = {
  loading: false,
  policyName: 'Block Critical Security Findings',
  findings: [
    { severity: 'critical', name: 'Use of hard-coded password' },
    { severity: 'high', name: 'Use of API key' },
  ],
};

export const Passed = Template.bind({});
Passed.args = {
  loading: false,
  policyName: 'Block Critical Security Findings',
  findings: [],
};

export const Loading = Template.bind({});
Loading.args = {
  loading: true,
  policyName: 'Block Critical Security Findings',
  findings: [],
};

export default {
  title: 'merge_requests/reports/security_list_item',
  component: SecurityListItem,
};

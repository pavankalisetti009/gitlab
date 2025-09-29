import DataExplorer from './data_explorer.vue';

export default {
  component: DataExplorer,
  title: 'ee/data_explorer',
};

const Template = () => ({
  components: { DataExplorer },
  template: `<data-explorer />`,
});

export const Default = Template.bind({});

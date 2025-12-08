import DashboardList from './dashboard_list.vue';

export default {
  component: DashboardList,
  title: 'ee/analytics/analytics_dashboards/components/list/dashboard_list',
};

const Template = (args, { argTypes }) => ({
  components: { DashboardList },
  props: Object.keys(argTypes),
  template: `<dashboard-list :dashboards="dashboards" />`,
});

const defaultArgs = {
  dashboards: [
    {
      name: 'Built in dashboard',
      description: 'Built in dashboard',
      slug: 'built-in', // might need `url` instead once they are shareable
      user: {
        id: 1337,
        name: 'GitLab',
        username: 'gitlab',
        avatarUrl: '/fake/user/avatar.jpg',
      },
      isCustom: false,
      isStarred: true,
      shareLink: '/fake/link/to/share',
    },
    {
      name: 'First custom dashboard',
      description: 'Default dashboard description',
      slug: 'first-custom-dashboard',
      user: {
        id: 133737,
        name: 'Fake User',
        username: 'fakeuser',
        avatarUrl: '/fake/user/avatar.jpg',
      },
      isCustom: true,
      isStarred: false,
      isEditable: true,
      shareLink: '/fake/link/to/share',
      lastEdited: '2025-09-10',
    },
    {
      name: 'Cool dashboard',
      description:
        'Cool custom dashboard that has a description that is very long and will most definitely overflow within its box because its long',
      slug: 'cool-custom-dashboard',
      user: {
        id: 133737,
        name: 'Fake User',
        username: 'fakeuser',
        avatarUrl: '/fake/user/avatar.jpg',
      },
      isCustom: true,
      isStarred: false,
      isEditable: true,
      shareLink: '/fake/link/to/share',
      lastEdited: '2025-10-28',
    },
  ],
};

export const Default = Template.bind({});
Default.args = defaultArgs;

import MavenUpstreamDetailsApp from './maven_upstream_details_app.vue';

export default {
  component: MavenUpstreamDetailsApp,
  title: 'ee/virtual_registries/maven_upstream_details',
};

const Template = (_, { argTypes }) => ({
  components: { MavenUpstreamDetailsApp },
  props: Object.keys(argTypes),
  template: '<maven-upstream-details-app v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  upstream: {
    name: 'Upstream title',
    description: 'Upstream description',
    registryType: 'maven',
    url: 'http://maven.org/test',
    cacheValidityHours: 24,
    cacheEntries: {
      count: 1,
    },
  },
  cacheEntries: {
    count: 1,
    nodes: [
      {
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Cache::Entry/1',
        fileMd5: null,
        fileSha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83',
        size: 15,
        relativePath: '/test/bar',
        contentType: 'application/octet-stream',
        upstreamCheckedAt: '2025-04-10T01:27:41Z',
      },
    ],
    pageInfo: {
      startCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
      hasNextPage: false,
      hasPreviousPage: false,
      endCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
    },
  },
};

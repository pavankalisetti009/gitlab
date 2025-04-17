import MavenRegistryDetailsApp from './maven_registry_details_app.vue';

export default {
  component: MavenRegistryDetailsApp,
  title: 'ee/virtual_registries/maven_registry_details',
};

const Template = (_, { argTypes }) => ({
  components: { MavenRegistryDetailsApp },
  props: Object.keys(argTypes),
  provide: {
    updateVirtualRegistry: true,
    mavenVirtualRegistryEditPath: 'edit_path',
  },
  template: '<maven-registry-details-app v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  registry: {
    id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
    name: 'Registry title',
    description: 'Registry description',
  },
  upstreams: {
    count: 1,
    nodes: [
      {
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
        name: 'Upstream title',
        description: 'Upstream description',
        url: 'http://maven.org/test',
        cacheValidityHours: 24,
        position: 1,
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

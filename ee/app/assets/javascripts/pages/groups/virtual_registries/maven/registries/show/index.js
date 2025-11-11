import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries/show.vue';

initSimpleApp('#js-vue-maven-registry-details', MavenRegistryDetailsApp, {
  withApolloProvider: true,
  name: 'MavenRegistryDetails',
});

import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenVirtualRegistriesAndUpstreamsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries_and_upstreams/index.vue';

initSimpleApp(
  '#js-vue-maven-virtual-registries-and-upstreams',
  MavenVirtualRegistriesAndUpstreamsApp,
  {
    withApolloProvider: true,
    name: 'MavenVirtualRegistriesAndUpstreamsRoot',
  },
);

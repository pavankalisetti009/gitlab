import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenUpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/upstreams/show.vue';

initSimpleApp('#js-vue-maven-upstream-details', MavenUpstreamDetailsApp, {
  name: 'MavenUpstreamDetails',
});

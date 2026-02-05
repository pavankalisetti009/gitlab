import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { concatPagination } from '@apollo/client/utilities';
import createDefaultClient from '~/lib/graphql';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries/show.vue';
import getUpstreamsSelectQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_select.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import getUpstreamSummaryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_summary.query.graphql';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          Group: {
            fields: {
              virtualRegistriesPackagesMavenUpstreams: {
                merge: true,
                keyArgs: ['groupPath', 'upstreamName'],
              },
            },
          },
          MavenUpstreamConnection: {
            fields: {
              nodes: concatPagination(),
            },
          },
        },
      },
    },
  ),
});

initSimpleApp('#js-vue-maven-registry-details', MavenRegistryDetailsApp, {
  withApolloProvider: apolloProvider,
  name: 'MavenRegistryDetails',
  additionalProvide: {
    getUpstreamsCountQuery,
    getUpstreamsSelectQuery,
    getUpstreamSummaryQuery,
  },
});

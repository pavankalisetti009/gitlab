<script>
import MavenRegistryDetails from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import getMavenVirtualRegistryUpstreams from '../graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import { convertToMavenRegistryGraphQLId } from '../utils';
import { captureException } from '../sentry_utils';

export default {
  name: 'RegistryDetailsRoot',
  components: {
    MavenRegistryDetails,
  },
  inject: {
    registry: {
      default: {},
    },
    registryEditPath: {
      default: '',
    },
    groupPath: {
      default: '',
    },
  },
  data() {
    return {
      group: {},
      mavenVirtualRegistryID: convertToMavenRegistryGraphQLId(this.registry.id),
    };
  },
  apollo: {
    group: {
      query: getMavenVirtualRegistryUpstreams,
      variables() {
        return {
          groupPath: this.groupPath,
          mavenVirtualRegistryID: this.mavenVirtualRegistryID,
        };
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    upstreams() {
      if (Object.keys(this.group).length === 0) {
        return {};
      }

      const { mavenVirtualRegistries } = this.group;
      const { upstreams } = mavenVirtualRegistries.nodes[0];

      return {
        count: upstreams.length,
        nodes: upstreams,
      };
    },
  },
  methods: {
    refetchGroupQuery() {
      this.$apollo.queries.group.refetch();
    },
  },
};
</script>
<template>
  <maven-registry-details
    :registry="registry"
    :upstreams="upstreams"
    @upstreamCreated="refetchGroupQuery"
  />
</template>

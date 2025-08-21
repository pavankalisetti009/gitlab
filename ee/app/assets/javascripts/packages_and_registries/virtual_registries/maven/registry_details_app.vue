<script>
import MavenRegistryDetails from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import MavenRegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_header.vue';
import getMavenVirtualRegistryUpstreams from '../graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import { convertToMavenRegistryGraphQLId } from '../utils';
import { captureException } from '../sentry_utils';

export default {
  name: 'RegistryDetailsRoot',
  components: {
    MavenRegistryDetails,
    MavenRegistryDetailsHeader,
  },
  inject: {
    registry: {
      default: {},
    },
  },
  data() {
    return {
      mavenVirtualRegistry: {},
      mavenVirtualRegistryID: convertToMavenRegistryGraphQLId(this.registry.id),
    };
  },
  apollo: {
    mavenVirtualRegistry: {
      query: getMavenVirtualRegistryUpstreams,
      variables() {
        return {
          id: this.mavenVirtualRegistryID,
        };
      },
      update(data) {
        return data.mavenVirtualRegistry || {};
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    upstreams() {
      return this.mavenVirtualRegistry?.upstreams ?? [];
    },
  },
  methods: {
    refetchMavenVirtualRegistryQuery() {
      this.$apollo.queries.mavenVirtualRegistry.refetch();
    },
  },
};
</script>
<template>
  <div>
    <maven-registry-details-header />
    <maven-registry-details
      :registry-id="registry.id"
      :upstreams="upstreams"
      @upstreamCreated="refetchMavenVirtualRegistryQuery"
      @upstreamReordered="refetchMavenVirtualRegistryQuery"
    />
  </div>
</template>

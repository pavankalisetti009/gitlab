<script>
import MavenRegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/header.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/upstreams_list.vue';
import getMavenVirtualRegistryUpstreams from '../../../graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import { convertToMavenRegistryGraphQLId } from '../../../utils';
import { captureException } from '../../../sentry_utils';

export default {
  name: 'MavenRegistryDetailsApp',
  components: {
    MavenRegistryDetailsHeader,
    UpstreamsList,
  },
  inject: {
    registry: {
      default: {},
    },
  },
  data() {
    return {
      hasLoadedOnce: false,
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
      result() {
        this.hasLoadedOnce = true;
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    isFirstTimeLoading() {
      return this.$apollo.queries.mavenVirtualRegistry.loading && !this.hasLoadedOnce;
    },
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
    <upstreams-list
      :loading="isFirstTimeLoading"
      :registry-id="registry.id"
      :upstreams="upstreams"
      @upstreamCreated="refetchMavenVirtualRegistryQuery"
      @upstreamLinked="refetchMavenVirtualRegistryQuery"
      @upstreamReordered="refetchMavenVirtualRegistryQuery"
      @upstreamRemoved="refetchMavenVirtualRegistryQuery"
    />
  </div>
</template>

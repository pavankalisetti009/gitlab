<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import { n__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue';
import upstreamsFetchMixin from 'ee/packages_and_registries/virtual_registries/mixins/upstreams/fetch';
import { CONTAINER_REGISTRIES_INDEX, CONTAINER_UPSTREAMS_INDEX } from './routes';

export default {
  name: 'ContainerRegistriesAndUpstreams',
  components: {
    GlTabs,
    GlTab,
    CleanupPolicyStatus,
    PageHeading,
    RegistriesList,
    UpstreamsList,
  },
  mixins: [upstreamsFetchMixin],
  inject: ['fullPath'],
  data() {
    return {
      registriesCount: null,
    };
  },
  computed: {
    isRegistriesRoute() {
      return this.$route.name === CONTAINER_REGISTRIES_INDEX;
    },
    isUpstreamsRoute() {
      return this.$route.name === CONTAINER_UPSTREAMS_INDEX;
    },
    registriesTabAttributes() {
      return { href: this.$router.resolve({ name: CONTAINER_REGISTRIES_INDEX }).href };
    },
    upstreamsTabAttributes() {
      return { href: this.$router.resolve({ name: CONTAINER_UPSTREAMS_INDEX }).href };
    },
    registriesTabCountSRText() {
      if (this.registriesCount === null) return '';

      return n__(
        'VirtualRegistry|%d registry',
        'VirtualRegistry|%d registries',
        this.registriesCount,
      );
    },
  },
  methods: {
    handleRegistriesTabClick() {
      this.$router.push({ name: CONTAINER_REGISTRIES_INDEX });
    },
    handleUpstreamsTabClick() {
      this.$router.push({ name: CONTAINER_UPSTREAMS_INDEX });
    },
    updateRegistriesCount(newCount) {
      this.registriesCount = newCount;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('VirtualRegistry|Container virtual registries')" />
    <cleanup-policy-status batch-key="ContainerVirtualRegistries" />
    <gl-tabs content-class="gl-p-0">
      <gl-tab
        :title="s__('VirtualRegistry|Registries')"
        :tab-count="registriesCount"
        :tab-count-sr-text="registriesTabCountSRText"
        :active="isRegistriesRoute"
        :title-link-attributes="registriesTabAttributes"
        @click="handleRegistriesTabClick"
      >
        <registries-list @update-count="updateRegistriesCount" />
      </gl-tab>
      <gl-tab
        :title="s__('VirtualRegistry|Upstreams')"
        :tab-count="upstreamsCount"
        :tab-count-sr-text="upstreamsTabCountSRText"
        :active="isUpstreamsRoute"
        :title-link-attributes="upstreamsTabAttributes"
        @click="handleUpstreamsTabClick"
      >
        <upstreams-list
          :upstreams="upstreams"
          :loading="$apollo.queries.upstreams.loading"
          :search-term="upstreamsSearchTerm"
          @submit="handleUpstreamsSearch"
          @page-change="handleUpstreamsPagination"
        />
      </gl-tab>
    </gl-tabs>
  </div>
</template>

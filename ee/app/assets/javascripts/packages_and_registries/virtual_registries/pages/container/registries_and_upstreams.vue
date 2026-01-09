<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import { CONTAINER_REGISTRIES_INDEX, CONTAINER_UPSTREAMS_INDEX } from './routes';

export default {
  name: 'ContainerRegistriesAndUpstreams',
  components: {
    GlTabs,
    GlTab,
    CleanupPolicyStatus,
    PageHeading,
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
  },
  methods: {
    handleRegistriesTabClick() {
      this.$router.push({ name: CONTAINER_REGISTRIES_INDEX });
    },
    handleUpstreamsTabClick() {
      this.$router.push({ name: CONTAINER_UPSTREAMS_INDEX });
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
        :active="isRegistriesRoute"
        :title-link-attributes="registriesTabAttributes"
        @click="handleRegistriesTabClick"
      >
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        {{ 'registries tab coming soon' }}
      </gl-tab>
      <gl-tab
        :title="s__('VirtualRegistry|Upstreams')"
        :active="isUpstreamsRoute"
        :title-link-attributes="upstreamsTabAttributes"
        @click="handleUpstreamsTabClick"
      >
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        {{ 'upstreams tab coming soon' }}
      </gl-tab>
    </gl-tabs>
  </div>
</template>

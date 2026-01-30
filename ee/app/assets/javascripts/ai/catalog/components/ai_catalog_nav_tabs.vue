<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import { s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_FLOWS_ROUTE } from '../router/constants';

export default {
  components: {
    GlTab,
    GlTabs,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  computed: {
    tabs() {
      return [
        {
          text: s__('AICatalog|Agents'),
          route: AI_CATALOG_AGENTS_ROUTE,
          active: !this.$route.path.startsWith(AI_CATALOG_FLOWS_ROUTE),
        },
        ...(this.glAbilities.readAiCatalogFlow ?? this.glFeatures.aiCatalogFlows
          ? [
              {
                text: s__('AICatalog|Flows'),
                route: AI_CATALOG_FLOWS_ROUTE,
                active: this.$route.path.startsWith(AI_CATALOG_FLOWS_ROUTE),
              },
            ]
          : []),
      ];
    },
  },
  methods: {
    navigateTo(route) {
      if (this.$route.name !== route) {
        this.$router.push({ name: route, query: this.$route.query });
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-grow @lg/panel:gl-items-center">
    <gl-tabs content-class="gl-py-0">
      <gl-tab
        v-for="tab in tabs"
        :key="tab.text"
        :title="tab.text"
        :active="tab.active"
        @click="navigateTo(tab.route)"
      />
    </gl-tabs>
  </div>
</template>

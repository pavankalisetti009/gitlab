<script>
import CeGroupSettingsApp from '~/packages_and_registries/settings/group/components/group_settings_app.vue';
import VirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/components/virtual_registries_setting.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';

export default {
  name: 'GroupSettingsAppEE',
  components: {
    CeGroupSettingsApp,
    VirtualRegistriesSetting,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin(), glLicensedFeaturesMixin()],
  computed: {
    hasVirtualRegistryFeatureFlags() {
      return this.glFeatures.mavenVirtualRegistry && this.glFeatures.uiForVirtualRegistries;
    },
    hasVirtualRegistryAccess() {
      return (
        this.glLicensedFeatures.packagesVirtualRegistry && this.glAbilities.adminVirtualRegistry
      );
    },
    shouldRenderVirtualRegistriesSetting() {
      return this.hasVirtualRegistryFeatureFlags && this.hasVirtualRegistryAccess;
    },
  },
};
</script>

<template>
  <ce-group-settings-app>
    <template #virtual-registries-setting="{ handleSuccess, handleError }">
      <virtual-registries-setting
        v-if="shouldRenderVirtualRegistriesSetting"
        id="virtual-registries-setting"
        @success="handleSuccess"
        @error="handleError"
      />
    </template>
  </ce-group-settings-app>
</template>

<script>
import { GlAlert, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import getDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/queries/get_dependency_proxy_packages_settings.query.graphql';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'DependencyProxyPackagesSettings',
  components: {
    DependencyProxyPackagesSettingsForm,
    GlAlert,
    GlCard,
    GlSkeletonLoader,
    SettingsSection,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    projectPath: {
      default: '',
    },
  },
  apollo: {
    dependencyProxyPackagesSettings: {
      query: getDependencyProxyPackagesSettings,
      context: {
        batchKey: 'PackageRegistryProjectSettings',
      },
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project?.dependencyProxyPackagesSetting || {},
      error(e) {
        this.fetchSettingsError = e;
        Sentry.captureException(e);
      },
    },
  },
  data() {
    return {
      dependencyProxyPackagesSettings: {},
      fetchSettingsError: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.dependencyProxyPackagesSettings.loading;
    },
    featureFlagEnabled() {
      return this.glFeatures.reorganizeProjectLevelRegistrySettings;
    },
  },
};
</script>

<template>
  <gl-card v-if="featureFlagEnabled" data-testid="dependency-proxy-settings">
    <template #header>
      <h2 class="gl-m-0 gl-inline-flex gl-items-center gl-text-base gl-font-bold gl-leading-normal">
        {{ s__('DependencyProxy|Dependency Proxy') }}
      </h2>
    </template>
    <template #default>
      <p class="gl-text-subtle" data-testid="description">
        {{
          s__(
            'DependencyProxy|Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
          )
        }}
      </p>

      <gl-alert v-if="fetchSettingsError" variant="warning" :dismissible="false">
        {{
          s__('DependencyProxy|Something went wrong while fetching the dependency proxy settings.')
        }}
      </gl-alert>

      <gl-skeleton-loader v-else-if="isLoading" />
      <dependency-proxy-packages-settings-form v-else :data="dependencyProxyPackagesSettings" />
    </template>
  </gl-card>
  <settings-section
    v-else
    :heading="s__('DependencyProxy|Dependency Proxy')"
    :description="
      s__(
        'DependencyProxy|Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
      )
    "
    data-testid="dependency-proxy-settings"
  >
    <template #default>
      <gl-alert v-if="fetchSettingsError" variant="warning" :dismissible="false">
        {{
          s__('DependencyProxy|Something went wrong while fetching the dependency proxy settings.')
        }}
      </gl-alert>
      <gl-skeleton-loader v-else-if="isLoading" />
      <dependency-proxy-packages-settings-form v-else :data="dependencyProxyPackagesSettings" />
    </template>
  </settings-section>
</template>

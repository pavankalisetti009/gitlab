<script>
import { GlExperimentBadge, GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_FLOWS_SHOW_ROUTE, AI_CATALOG_FLOWS_DUPLICATE_ROUTE } from '../router/constants';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG, AI_CATALOG_TYPE_FLOW } from '../constants';
import AiCatalogFlowForm from '../components/ai_catalog_flow_form.vue';

export default {
  name: 'AiCatalogFlowsEdit',
  components: {
    AiCatalogFlowForm,
    GlExperimentBadge,
    PageHeading,
    GlAlert,
    GlLink,
    GlSprintf,
  },
  props: {
    aiCatalogFlow: {
      type: Object,
      required: true,
    },
    version: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    shouldShowEditingLatestAlert() {
      return this.version.isUpdateAvailable;
    },
    duplicateLink() {
      return {
        name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
        params: { id: this.$route.params.id },
      };
    },
    initialValues() {
      return {
        projectId: this.aiCatalogFlow.project?.id,
        name: this.aiCatalogFlow.name,
        description: this.aiCatalogFlow.description,
        public: this.aiCatalogFlow.public,
        definition: this.aiCatalogFlow.latestVersion.definition,
      };
    },
    canAdmin() {
      return Boolean(this.aiCatalogFlow.userPermissions?.adminAiCatalogItem);
    },
  },
  created() {
    if (!this.canAdmin) {
      this.$router.push({
        name: AI_CATALOG_FLOWS_SHOW_ROUTE,
        params: { id: this.$route.params.id },
      });
    }
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].update;
      const originalItemUpdatedAt = this.aiCatalogFlow.updatedAt;
      const originalVersionUpdatedAt = this.aiCatalogFlow.latestVersion.updatedAt;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input: {
              id: this.aiCatalogFlow.id,
              ...input,
            },
          },
        });

        if (data) {
          const { errors, item } = data[config.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const itemWasUpdated = item.updatedAt !== originalItemUpdatedAt;
          const versionWasUpdated = item.latestVersion.updatedAt !== originalVersionUpdatedAt;
          if (itemWasUpdated || versionWasUpdated) {
            this.$toast.show(s__('AICatalog|Flow updated.'));
          }
          this.$router.push({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not update flow. Try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          {{ s__('AICatalog|Edit flow') }}
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </span>
      </template>
      <template #description>
        {{ s__('AICatalog|Manage flow settings.') }}
      </template>
    </page-heading>
    <gl-alert
      v-if="shouldShowEditingLatestAlert"
      :dismissible="false"
      variant="warning"
      class="gl-my-6"
    >
      <gl-sprintf
        :message="
          s__(
            'AICatalog|To prevent versioning issues, you can edit only the latest version of this flow. To edit an earlier version, %{linkStart}duplicate the flow%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :to="duplicateLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <ai-catalog-flow-form
      mode="edit"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>

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
    definition() {
      return this.aiCatalogFlow.latestVersion.definition;
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
        definition: this.definition,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].update;

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
          const { errors } = data[config.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Flow updated.'));
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
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Manage flow settings.') }}
        </div>
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

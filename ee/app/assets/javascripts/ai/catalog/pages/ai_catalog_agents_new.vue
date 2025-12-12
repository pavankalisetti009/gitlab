<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { prerequisitesError } from '../utils';

export default {
  name: 'AiCatalogAgentsNew',
  components: {
    AiCatalogAgentForm,
    PageHeading,
    GlExperimentBadge,
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
      selectedItemType: null,
    };
  },
  computed: {
    isThirdPartyFlow() {
      return this.selectedItemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
  },
  methods: {
    async handleSubmit({ type, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[type].create;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors, item } = data[config.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const newAgentId = getIdFromGraphQLId(item.id);
          this.$toast.show(s__('AICatalog|Agent created.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: newAgentId },
          });
        }
      } catch (error) {
        this.errors = [
          prerequisitesError(
            s__(
              'AICatalog|Could not create agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
          ),
        ];
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
          {{ s__('AICatalog|New agent') }}
          <gl-experiment-badge
            :type="isThirdPartyFlow ? 'experiment' : 'beta'"
            class="gl-self-center"
          />
        </span>
      </template>
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{
            s__(
              'AICatalog|Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
            )
          }}
        </div>
      </template>
    </page-heading>

    <ai-catalog-agent-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @select-item-type="selectedItemType = $event"
      @submit="handleSubmit"
    />
  </div>
</template>

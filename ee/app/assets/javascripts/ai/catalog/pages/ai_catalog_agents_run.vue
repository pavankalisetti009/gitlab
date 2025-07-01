<script>
import { GlButton, GlFormGroup, GlFormTextarea } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    GlButton,
    GlFormGroup,
    GlFormTextarea,
    PageHeading,
  },
  data() {
    return {
      prompt: '',
      isSubmitting: false,
    };
  },
  computed: {
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.$route.params.id}`;
    },
  },
  methods: {
    onBack() {
      // TODO: Consider routing strategy for "back" navigation
      // Currently using hardcoded routes to go "back" to previous page in user flow.
      // Issue: Users could theoretically come from anywhere, then get routed back to
      // whatever is in history, which may not be the intended previous step.
      // For now, keeping this approach but may need to revisit if we implement
      // run page in drawer or need more sophisticated navigation handling.
      this.$router.back();
    },
    async onSubmit() {
      this.isSubmitting = true;

      try {
        this.$toast.show(this.prompt);
      } catch (error) {
        this.$toast.show(s__('AICatalog|Failed to run agent.'));
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-button data-testid="ai-catalog-back-button" @click="onBack">
      {{ __('Go back') }}
    </gl-button>

    <page-heading :heading="pageTitle" />

    <form @submit.prevent="onSubmit">
      <gl-form-group :label="s__('AICatalog|Prompt')" label-for="prompt-textarea">
        <gl-form-textarea id="prompt-textarea" v-model="prompt" :no-resize="false" rows="6" />
      </gl-form-group>

      <gl-button
        type="submit"
        variant="confirm"
        class="js-no-auto-disable"
        :loading="isSubmitting"
        data-testid="ai-catalog-run-button"
      >
        {{ s__('AICatalog|Run') }}
      </gl-button>
    </form>
  </div>
</template>

<script>
import {
  GlAlert,
  GlButton,
  GlCard,
  GlCollapsibleListbox,
  GlForm,
  GlFormGroup,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { sprintf, n__ } from '~/locale';
import { getMavenUpstream } from 'ee/api/virtual_registries_api';
import { captureException } from '../sentry_utils';
import TestMavenUpstreamButton from './test_maven_upstream_button.vue';

export default {
  name: 'LinkUpstreamForm',
  components: {
    GlAlert,
    GlButton,
    GlCard,
    GlCollapsibleListbox,
    GlForm,
    GlFormGroup,
    GlSkeletonLoader,
    TestMavenUpstreamButton,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    upstreamOptions: {
      type: Array,
      required: true,
    },
  },
  /**
   * @event submit - Emitted when the form is submitted
   * @property {String} upstreamId - The ID of the selected upstream
   */
  /**
   * @event cancel - Emitted when the "Cancel" button is clicked
   */
  emits: ['submit', 'cancel'],
  data() {
    return {
      fetchUpstreamDetailsError: false,
      isFetchingUpstreamDetails: false,
      selectedUpstream: null,
      selectedUpstreamDetails: null,
    };
  },
  computed: {
    hasOptions() {
      return this.upstreamOptions.length > 0;
    },
  },
  methods: {
    async fetchUpstreamDetails(upstreamId) {
      if (!upstreamId) return;

      this.fetchUpstreamDetailsError = false;
      this.isFetchingUpstreamDetails = true;
      this.selectedUpstreamDetails = null;
      try {
        const response = await getMavenUpstream({ id: upstreamId });
        this.selectedUpstreamDetails = response.data;
      } catch (error) {
        this.fetchUpstreamDetailsError = true;
        captureException({ error, component: this.$options.name });
      } finally {
        this.isFetchingUpstreamDetails = false;
      }
    },
    getCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__('VirtualRegistry|%{hours} hour', 'VirtualRegistry|%{hours} hours', cacheValidityHours),
        { hours: cacheValidityHours },
      );
    },
    submit() {
      if (this.selectedUpstream) {
        this.$emit('submit', this.selectedUpstream);
      }
    },
    cancel() {
      this.$emit('cancel');
    },
  },
  rowClass: 'md:gl-text-right md:gl-basis-26',
};
</script>

<template>
  <gl-form v-if="hasOptions" @submit.prevent="submit">
    <gl-form-group
      id="upstream-select"
      :label="s__('VirtualRegistry|Select an upstream')"
      class="md:gl-w-3/10"
    >
      <gl-collapsible-listbox
        v-model="selectedUpstream"
        block
        toggle-aria-labelled-by="upstream-select"
        :items="upstreamOptions"
        @select="fetchUpstreamDetails"
      >
        <template #list-item="{ item }">
          <div class="gl-whitespace-nowrap">{{ item.text }}</div>
          <div class="gl-text-subtle">{{ item.secondaryText }}</div>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>
    <gl-card class="gl-my-3" header-class="gl-bg-subtle" body-class="gl-p-0">
      <template #header>
        <span class="gl-font-bold">{{ s__('VirtualRegistry|Upstream summary') }}</span>
      </template>
      <template #default>
        <div v-if="selectedUpstreamDetails">
          <div class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 md:gl-flex-row md:gl-gap-5">
            <span :class="$options.rowClass"> {{ s__('VirtualRegistry|URL') }}</span>
            <span> {{ selectedUpstreamDetails.url }}</span>
          </div>
          <div
            v-if="selectedUpstreamDetails.description"
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 md:gl-flex-row md:gl-gap-5"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Description') }}
            </span>
            <span> {{ selectedUpstreamDetails.description }} </span>
          </div>
          <div class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 md:gl-flex-row md:gl-gap-5">
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Caching period') }}
            </span>
            <span>
              {{ getCacheValidityHoursLabel(selectedUpstreamDetails.cache_validity_hours) }}
            </span>
          </div>
          <div class="gl-flex gl-flex-col gl-px-5 gl-py-4 md:gl-flex-row md:gl-gap-5">
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Metadata caching period') }}
            </span>
            <span>
              {{
                getCacheValidityHoursLabel(selectedUpstreamDetails.metadata_cache_validity_hours)
              }}
            </span>
          </div>
        </div>
        <div v-else class="gl-px-5 gl-py-4">
          <gl-skeleton-loader v-if="isFetchingUpstreamDetails" :lines="3" />
          <gl-alert
            v-else-if="fetchUpstreamDetailsError"
            variant="danger"
            @dismiss="fetchUpstreamDetailsError = false"
          >
            {{ s__('VirtualRegistry|Failed to fetch upstream summary.') }}
          </gl-alert>
          <div v-else>
            {{ s__('VirtualRegistry|To view summary, select an upstream.') }}
          </div>
        </div>
      </template>
    </gl-card>
    <div class="gl-flex gl-gap-3">
      <gl-button
        data-testid="submit-button"
        class="js-no-auto-disable"
        variant="confirm"
        category="primary"
        type="submit"
        :loading="loading"
      >
        {{ s__('VirtualRegistry|Add upstream') }}
      </gl-button>
      <gl-button data-testid="cancel-button" category="secondary" @click="cancel">
        {{ __('Cancel') }}
      </gl-button>
      <test-maven-upstream-button
        v-if="selectedUpstreamDetails"
        :upstream-id="selectedUpstreamDetails.id"
      />
    </div>
  </gl-form>
</template>

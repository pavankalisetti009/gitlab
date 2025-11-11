<script>
import { GlAlert, GlButton, GlCard, GlForm, GlFormGroup, GlSkeletonLoader } from '@gitlab/ui';
import { sprintf, n__ } from '~/locale';
import { getMavenUpstream } from 'ee/api/virtual_registries_api';
import { captureException } from '../../../../sentry_utils';
import TestMavenUpstreamButton from '../../shared/test_maven_upstream_button.vue';
import UpstreamSelector from './upstream_selector.vue';

export default {
  name: 'LinkUpstreamForm',
  components: {
    GlAlert,
    GlButton,
    GlCard,
    GlForm,
    GlFormGroup,
    GlSkeletonLoader,
    TestMavenUpstreamButton,
    UpstreamSelector,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    linkedUpstreams: {
      type: Array,
      required: true,
    },
    initialUpstreams: {
      type: Array,
      required: true,
    },
    upstreamsCount: {
      type: Number,
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
    selectedUpstreamName() {
      return this.selectedUpstreamDetails?.name ?? '';
    },
  },
  methods: {
    async selectUpstream(upstreamId) {
      if (!upstreamId) return;

      this.selectedUpstream = upstreamId;

      this.fetchUpstreamDetailsError = false;
      this.isFetchingUpstreamDetails = true;
      try {
        const response = await getMavenUpstream({ id: upstreamId });
        this.selectedUpstreamDetails = response.data;
      } catch (error) {
        this.fetchUpstreamDetailsError = true;
        this.selectedUpstreamDetails = null;
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
  rowClass: '@md/panel:gl-text-right @md/panel:gl-basis-26',
};
</script>

<template>
  <gl-form @submit.prevent="submit">
    <gl-form-group
      id="upstream-select-group"
      :label="s__('VirtualRegistry|Select an upstream')"
      label-for="upstream-select"
      class="@md/panel:gl-w-3/10"
    >
      <upstream-selector
        :selected-upstream-name="selectedUpstreamName"
        :linked-upstreams="linkedUpstreams"
        :upstreams-count="upstreamsCount"
        :initial-upstreams="initialUpstreams"
        @select="selectUpstream"
      />
    </gl-form-group>
    <gl-card class="gl-my-3" header-class="gl-bg-subtle" body-class="gl-p-0">
      <template #header>
        <span class="gl-font-bold">{{ s__('VirtualRegistry|Upstream summary') }}</span>
      </template>
      <template #default>
        <div v-if="selectedUpstreamDetails">
          <div
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass"> {{ s__('VirtualRegistry|URL') }}</span>
            <span> {{ selectedUpstreamDetails.url }}</span>
          </div>
          <div
            v-if="selectedUpstreamDetails.description"
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Description') }}
            </span>
            <span> {{ selectedUpstreamDetails.description }} </span>
          </div>
          <div
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Artifact caching period') }}
            </span>
            <span>
              {{ getCacheValidityHoursLabel(selectedUpstreamDetails.cache_validity_hours) }}
            </span>
          </div>
          <div class="gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5">
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

<script>
import {
  GlModal,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlSearchBoxByType,
  GlFormRadioGroup,
  GlFormRadio,
  GlLoadingIcon,
} from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import LifecycleDetail from './lifecycle_detail.vue';
import namespaceStatusesQuery from './namespace_lifecycles.query.graphql';
import namespaceDefaultLifecycleQuery from './namespace_default_lifecycle.query.graphql';

export default {
  name: 'CreateLifecycle',
  components: {
    GlModal,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    LifecycleDetail,
    GlSearchBoxByType,
    GlFormRadioGroup,
    GlFormRadio,
    GlLoadingIcon,
  },
  i18n: {
    createLifecycle: s__('WorkItem|Create lifecycle'),
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      errorText: '',
      searchTerm: '',
      lifecycles: [],
      defaultLifecycle: {},
      formData: {
        name: '',
        selectedLifecycleId: 'gid://gitlab/Lifecycle/default',
      },
    };
  },
  apollo: {
    lifecycles: {
      query: namespaceStatusesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      skip() {
        return !this.visible;
      },
      update(data) {
        return data.namespace?.lifecycles?.nodes || [];
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load statuses.');
        Sentry.captureException(error);
      },
    },
    defaultLifecycle: {
      query: namespaceDefaultLifecycleQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespaceDefaultLifecycle?.lifecycle || {};
      },
      skip() {
        return !this.visible;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load default lifecycle');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    fetchingLifecycles() {
      return this.$apollo.queries.lifecycles.loading;
    },
    fetchingDefaultLifecycle() {
      return this.$apollo.queries.defaultLifecycle.loading;
    },
    filteredLifecycles() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.lifecycles, this.searchTerm, {
          key: ['name'],
        });
      }
      return this.lifecycles;
    },
    allLifecycles() {
      return [this.defaultLifecycle, ...this.lifecycles];
    },
    selectedLifecycle() {
      return (
        this.allLifecycles.find(
          (lifecycle) => this.formData.selectedLifecycleId === lifecycle.id,
        ) || {}
      );
    },
    // eslint-disable-next-line vue/no-unused-properties
    selectedLifecycleStatuses() {
      return this.selectedLifecycle.statuses;
    },
    showLoadingIndicator() {
      return this.fetchingDefaultLifecycle || this.fetchingLifecycles;
    },
  },
  methods: {
    closeAndResetData() {
      this.$emit('close');
      this.resetFormData();
    },
    closeModal() {
      this.closeAndResetData();
    },
    resetFormData() {
      this.formData = {
        selectedLifecycleId: 'gid://gitlab/Lifecycle/default',
        name: '',
      };
      this.searchTerm = '';
      this.errorText = '';
    },
    onSubmit() {
      /** TODO should create a new lifecycle on submit */
      this.closeAndResetData();
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    :title="$options.i18n.createLifecycle"
    scrollable
    modal-id="create-lifecycle-modal"
    @hide="closeModal"
  >
    <p>
      {{
        s__(
          'WorkItem|Creating a lifecycle will not effect existing items. Change the lifecycle associated with an item type to use this new lifecycle.',
        )
      }}
    </p>

    <gl-form>
      <gl-form-group
        label="Lifecycle name"
        invalid-feedback="Empty"
        label-size="sm"
        label-for="new-lifecycle-name"
        required
      >
        <gl-form-input
          id="new-lifecycle-name"
          v-model="formData.name"
          class="gl-w-34"
          data-testid="new-lifecycle-name-field"
        />
      </gl-form-group>

      <h5 class="gl-mb-0 gl-mt-6">{{ s__('WorkItem|Starting statuses') }}</h5>
      <p>
        {{
          s__(
            'WorkItem|Select a set of statuses to start from. You can edit statuses once the lifecycle created.',
          )
        }}
      </p>

      <div v-if="showLoadingIndicator">
        <gl-loading-icon size="lg" class="gl-p-4" />
      </div>
      <div v-else>
        <gl-form-radio-group v-model="formData.selectedLifecycleId" name="create-lifecycle-radio">
          <div class="gl-mb-3 gl-mt-5 gl-text-subtle">
            {{ s__('WorkItem|Start from a default configuration') }}
          </div>

          <div class="gl-border gl-rounded-lg gl-border-strong gl-bg-strong gl-p-4">
            <lifecycle-detail
              :lifecycle="defaultLifecycle"
              :class="{
                'gl-border-blue-500': formData.selectedLifecycleId === defaultLifecycle.id,
              }"
              is-default-lifecycle
              show-radio-selection
            >
              <template #radio-selection>
                <gl-form-radio :key="defaultLifecycle.id" :value="defaultLifecycle.id">
                  <span class="gl-font-bold">{{ s__('WorkItem|Default statuses') }}</span>
                </gl-form-radio>
              </template>
            </lifecycle-detail>
          </div>

          <div class="gl-mb-3 gl-mt-5 gl-text-subtle">
            {{ s__('WorkItem|Copy from existing lifecycle') }}
          </div>

          <div class="gl-border gl-rounded-lg gl-border-strong gl-bg-strong gl-p-4">
            <div class="gl-pb-3">
              <gl-search-box-by-type
                v-model="searchTerm"
                class="gl-w-34"
                :clear-button-title="__('Clear')"
                :placeholder="s__('WorkItem|Search lifecycles')"
              />
            </div>
            <div
              v-if="filteredLifecycles.length"
              class="gl-flex gl-max-h-31 gl-flex-col gl-gap-4 gl-overflow-y-auto"
            >
              <lifecycle-detail
                v-for="lifecycle in filteredLifecycles"
                :key="lifecycle.id"
                :class="{
                  'gl-border-blue-500': formData.selectedLifecycleId === lifecycle.id,
                }"
                :lifecycle="lifecycle"
                show-radio-selection
              >
                <template #radio-selection>
                  <gl-form-radio :key="lifecycle.id" :value="lifecycle.id">
                    <span class="gl-font-bold">{{ lifecycle.name }}</span>
                  </gl-form-radio>
                </template>
              </lifecycle-detail>
            </div>
            <div v-else class="gl-my-7 gl-text-center gl-text-subtle">
              {{ s__('WorkItem|No matching lifecycles.') }}
            </div>
          </div>
        </gl-form-radio-group>
      </div>
    </gl-form>

    <template #modal-footer>
      <gl-button data-testid="cancel-button" @click="closeModal">{{ __('Cancel') }}</gl-button>
      <gl-button data-testid="create-button" type="submit" variant="confirm" @click="onSubmit">{{
        __('Create')
      }}</gl-button>
    </template>
  </gl-modal>
</template>

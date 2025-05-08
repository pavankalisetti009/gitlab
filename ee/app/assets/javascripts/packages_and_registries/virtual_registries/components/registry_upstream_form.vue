<script>
import { GlForm, GlFormGroup, GlFormInput, GlFormTextarea, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  name: 'RegistryUpstreamForm',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlButton,
  },
  props: {
    /**
     * Whether the upstream can be tested
     */
    canTestUpstream: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    nameLabel: s__('VirtualRegistry|Name'),
    upstreamUrlLabel: s__('VirtualRegistry|Upstream URL'),
    descriptionLabel: s__('VirtualRegistry|Description (optional)'),
    usernameLabel: s__('VirtualRegistry|Username (optional)'),
    passwordLabel: s__('VirtualRegistry|Password (optional)'),
    passwordPlaceholder: s__('VirtualRegistry|Enter password'),
    cacheValidityHoursLabel: s__('VirtualRegistry|Caching period'),
    cacheValidityHoursHelpText: s__('VirtualRegistry|Time in hours'),
    createUpstreamButtonLabel: s__('VirtualRegistry|Create upstream'),
    testUpstreamButtonLabel: s__('VirtualRegistry|Test upstream'),
    cancelButtonLabel: __('Cancel'),
  },
  /**
   * @event createUpstream - Emitted when the "Create upstream" button is clicked
   * @property {Object} form - The form data
   */
  /**
   * @event testUpstream - Emitted when the "Test upstream" button is clicked
   * @property {Object} form - The form data
   */
  /**
   * @event cancel - Emitted when the "Cancel" button is clicked
   */
  emits: ['createUpstream', 'testUpstream', 'cancel'],
  data() {
    return {
      form: {
        name: '',
        upstreamUrl: '',
        description: '',
        username: '',
        password: '',
        cacheValidityHours: 24,
      },
    };
  },
  ids: {
    nameInputId: 'name-input',
    upstreamUrlInputId: 'upstream-url-input',
    descriptionInputId: 'description-input',
    usernameInputId: 'username-input',
    passwordInputId: 'password-input',
    cacheValidityHoursInputId: 'cache-validity-hours-input',
  },
  methods: {
    createUpstream() {
      this.$emit('createUpstream', this.form);
    },
    testUpstream() {
      this.$emit('testUpstream', this.form);
    },
    cancel() {
      this.$emit('cancel');
    },
  },
};
</script>
<template>
  <gl-form @submit.prevent="createUpstream">
    <gl-form-group
      data-testid="name-input"
      :label="$options.i18n.nameLabel"
      :label-for="$options.ids.nameInputId"
    >
      <gl-form-input :id="$options.ids.nameInputId" v-model="form.name" required autofocus />
    </gl-form-group>
    <gl-form-group
      data-testid="upstream-url-input"
      :label="$options.i18n.upstreamUrlLabel"
      :label-for="$options.ids.upstreamUrlInputId"
    >
      <gl-form-input :id="$options.ids.upstreamUrlInputId" v-model="form.upstreamUrl" required />
    </gl-form-group>
    <gl-form-group
      data-testid="description-input"
      :label="$options.i18n.descriptionLabel"
      :label-for="$options.ids.descriptionInputId"
    >
      <gl-form-textarea :id="$options.ids.descriptionInputId" v-model="form.description" />
    </gl-form-group>
    <gl-form-group
      data-testid="username-input"
      :label="$options.i18n.usernameLabel"
      :label-for="$options.ids.usernameInputId"
    >
      <gl-form-input :id="$options.ids.usernameInputId" v-model="form.username" />
    </gl-form-group>
    <gl-form-group
      data-testid="password-input"
      :label="$options.i18n.passwordLabel"
      :label-for="$options.ids.passwordInputId"
    >
      <gl-form-input :id="$options.ids.passwordInputId" v-model="form.password" type="password" />
    </gl-form-group>
    <gl-form-group
      data-testid="cache-validity-hours-input"
      :label="$options.i18n.cacheValidityHoursLabel"
      :label-for="$options.ids.cacheValidityHoursInputId"
      :label-description="$options.i18n.cacheValidityHoursHelpText"
    >
      <gl-form-input
        :id="$options.ids.cacheValidityHoursInputId"
        v-model="form.cacheValidityHours"
        class="gl-max-w-15"
        type="number"
        number
        :min="0"
      />
    </gl-form-group>
    <div class="gl-flex gl-gap-3">
      <gl-button
        data-testid="create-upstream-button"
        variant="confirm"
        category="primary"
        type="submit"
      >
        {{ $options.i18n.createUpstreamButtonLabel }}
      </gl-button>
      <gl-button data-testid="cancel-button" category="secondary" @click="cancel">
        {{ $options.i18n.cancelButtonLabel }}
      </gl-button>
      <gl-button
        v-if="canTestUpstream"
        data-testid="test-upstream-button"
        variant="confirm"
        category="tertiary"
        @click="testUpstream"
      >
        {{ $options.i18n.testUpstreamButtonLabel }}
      </gl-button>
    </div>
  </gl-form>
</template>

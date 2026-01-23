<script>
import { GlAlert, GlForm, GlFormFields, GlFormTextarea, GlButton } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__, sprintf } from '~/locale';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'RegistryForm',
  components: {
    GlAlert,
    GlForm,
    GlFormFields,
    GlFormTextarea,
    GlButton,
  },
  inject: ['fullPath', 'createRegistryMutation'],
  data() {
    return {
      submitting: false,
      errorMessages: [],
      registry: {
        name: '',
        description: '',
      },
    };
  },
  methods: {
    submit() {
      this.submitting = true;

      this.createRegistry()
        .catch((error) => {
          this.errorMessages = [__('Something went wrong. Please try again.')];

          captureException({ error, component: this.$options.name });
        })
        .finally(() => {
          this.submitting = false;
        });
    },
    createRegistry() {
      return this.$apollo.mutate({
        mutation: this.createRegistryMutation,
        variables: {
          input: {
            groupPath: this.fullPath,
            ...this.registry,
          },
        },
        update: (_, { data }) => {
          const { errors, ...result } = data.createRegistry;

          if (errors.length) {
            this.errorMessages = errors;
          } else {
            const { registry } = result;

            // TODO: Fix this when the detail page route is merged
            this.$router.push({
              name: 'container_registries_index',
              params: { id: getIdFromGraphQLId(registry.id) },
            });
          }
        },
      });
    },
  },
  fields: {
    name: {
      label: s__('VirtualRegistry|Name'),
      validators: [
        formValidators.required(s__('VirtualRegistry|Name is required.')),
        formValidators.factory(
          sprintf(s__('VirtualRegistry|Name cannot be longer than %{length} characters.'), {
            length: 255,
          }),
          (val) => val.length <= 255,
        ),
      ],
    },
    description: {
      label: s__('VirtualRegistry|Description (optional)'),
    },
  },
};
</script>
<template>
  <gl-form id="registry-form" class="@md/panel:gl-w-9/12">
    <gl-alert v-if="errorMessages.length" variant="danger" @dismiss="errorMessages = []">
      <ul class="!gl-mb-0 gl-ml-0 gl-pl-4">
        <li v-for="error in errorMessages" :key="error" data-testid="registry-error-message">
          {{ error }}
        </li>
      </ul>
    </gl-alert>
    <gl-form-fields
      v-model="registry"
      :fields="$options.fields"
      form-id="registry-form"
      data-testid="registry-form"
      @submit="submit"
    >
      <template #input(description)="{ id, input, value }">
        <gl-form-textarea :id="id" :value="value" @input="input" />
      </template>
    </gl-form-fields>
    <div class="gl-flex gl-gap-3">
      <gl-button class="js-no-auto-disable" variant="confirm" type="submit" :loading="submitting">
        {{ s__('VirtualRegistry|Create registry') }}
      </gl-button>
      <gl-button :to="{ path: '/' }">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </gl-form>
</template>

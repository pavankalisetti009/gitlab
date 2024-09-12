<script>
import { s__ } from '~/locale';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import updateSelfHostedModelMutation from '../graphql/mutations/update_self_hosted_model.mutation.graphql';
import { SELF_HOSTED_MODEL_MUTATIONS } from '../constants';
import SelfHostedModelForm from './self_hosted_model_form.vue';

export default {
  name: 'EditSelfHostedModel',
  components: {
    SelfHostedModelForm,
  },
  props: {
    basePath: {
      type: String,
      required: true,
    },
    model: {
      type: Object,
      required: true,
    },
    modelOptions: {
      type: Array,
      required: true,
    },
  },
  computed: {
    modelData() {
      return convertObjectPropsToCamelCase(this.model);
    },
  },
  i18n: {
    title: s__('AdminSelfHostedModels|Edit self-hosted model'),
    description: s__(
      'AdminSelfHostedModels|Edit the AI model that can be used for GitLab Duo features.',
    ),
  },
  mutationData: {
    name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
    mutation: updateSelfHostedModelMutation,
  },
};
</script>
<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p class="gl-pb-2 gl-pt-3">
      {{ $options.i18n.description }}
    </p>
    <self-hosted-model-form
      :initial-form-values="modelData"
      :base-path="basePath"
      :model-options="modelOptions"
      :mutation-data="$options.mutationData"
      :submit-button-text="s__('AdminSelfHostedModels|Edit self-hosted model')"
    />
  </div>
</template>

<script>
import { s__ } from '~/locale';
import selfHostedModelCreateMutation from '../graphql/mutations/create_self_hosted_model.mutation.graphql';
import SelfHostedModelForm from './self_hosted_model_form.vue';

const MUTATION_NAME = 'aiSelfHostedModelCreate';

export default {
  name: 'NewSelfHostedModel',
  components: {
    SelfHostedModelForm,
  },
  props: {
    basePath: {
      type: String,
      required: true,
    },
    modelOptions: {
      type: Array,
      required: true,
    },
  },
  i18n: {
    title: s__('AdminSelfHostedModels|Add self-hosted models'),
    description: s__(
      'AdminSelfHostedModels|Add a new AI model that can be used for GitLab Duo features.',
    ),
  },
  mutationData: {
    name: MUTATION_NAME,
    mutation: selfHostedModelCreateMutation,
  },
};
</script>
<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p class="gl-pt-3 gl-pb-2">
      {{ $options.i18n.description }}
    </p>
    <self-hosted-model-form
      :base-path="basePath"
      :model-options="modelOptions"
      :mutation-data="$options.mutationData"
    />
  </div>
</template>

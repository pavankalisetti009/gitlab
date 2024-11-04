<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import SelfHostedModelsTable from '../self_hosted_models/components/self_hosted_models_table.vue';
import getSelfHostedModelsQuery from '../self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';

export default {
  name: 'SelfHostedModelsPage',
  components: {
    SelfHostedModelsTable,
  },
  i18n: {
    errorMessage: s__(
      'AdminSelfHostedModels|An error occurred while loading self-hosted models. Please try again.',
    ),
  },
  data() {
    return {
      selfHostedModels: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
  },
  apollo: {
    selfHostedModels: {
      query: getSelfHostedModelsQuery,
      update(data) {
        return data.aiSelfHostedModels?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
};
</script>

<template>
  <self-hosted-models-table :models="selfHostedModels" :loading="isLoading" />
</template>

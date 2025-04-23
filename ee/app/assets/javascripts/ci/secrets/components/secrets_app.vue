<script>
export default {
  name: 'SecretsApp',
  methods: {
    showSecretsToast(message) {
      this.$toast.show(message);
    },
  },
};
</script>
<template>
  <router-view ref="router-view" @show-secrets-toast="showSecretsToast" />
</template>

<script>
export default {
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    systemPrompt() {
      return this.item.latestVersion?.systemPrompt;
    },
    userPrompt() {
      return this.item.latestVersion?.userPrompt;
    },
  },
};
</script>

<template>
  <div>
    <template v-if="systemPrompt">
      <dt>{{ s__('AICatalog|System prompt') }}</dt>
      <dd>{{ systemPrompt }}</dd>
    </template>
    <template v-if="userPrompt">
      <dt>{{ s__('AICatalog|User prompt') }}</dt>
      <dd>{{ userPrompt }}</dd>
    </template>
  </div>
</template>

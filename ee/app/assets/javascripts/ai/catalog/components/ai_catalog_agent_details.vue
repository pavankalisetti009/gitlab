<script>
import Markdown from '~/vue_shared/components/markdown/markdown_content.vue';

export default {
  components: {
    Markdown,
  },
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
    tools() {
      return this.item.latestVersion?.tools?.nodes.map((t) => t.title).join(', ');
    },
  },
};
</script>

<template>
  <div>
    <template v-if="systemPrompt">
      <dt>{{ s__('AICatalog|System prompt') }}</dt>
      <dd>
        <markdown :value="systemPrompt" />
      </dd>
    </template>
    <template v-if="userPrompt">
      <dt>{{ s__('AICatalog|User prompt') }}</dt>
      <dd>
        <markdown :value="userPrompt" />
      </dd>
    </template>
    <template v-if="tools">
      <dt>{{ s__('AICatalog|Tools') }}</dt>
      <dd>{{ tools }}</dd>
    </template>
  </div>
</template>

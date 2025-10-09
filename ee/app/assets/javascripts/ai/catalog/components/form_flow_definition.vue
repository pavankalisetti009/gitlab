<script>
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import SourceEditor from '~/vue_shared/components/source_editor.vue';

export default {
  name: 'FormFlowConfiguration',
  components: {
    ClipboardButton,
    SourceEditor,
  },
  props: {
    readOnly: {
      type: Boolean,
      required: false,
      default: false,
    },
    value: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    editorOptions() {
      return {
        padding: { top: 4 },
        readOnly: this.readOnly,
      };
    },
  },
  methods: {
    onInput(val) {
      this.$emit('input', val);
    },
  },
  configFile: 'config.yaml',
};
</script>

<template>
  <div class="gl-rounded-base gl-border-1 gl-border-solid gl-border-default">
    <div
      class="gl-flex gl-justify-between gl-border-b-1 gl-border-default gl-bg-subtle gl-px-5 gl-py-3 gl-border-b-solid"
      data-testid="flow-definition-header"
    >
      <strong>{{ $options.configFile }}</strong>
      <clipboard-button
        :text="value"
        :title="s__('AICatalog|Copy YAML configuration')"
        category="secondary"
        size="small"
      />
    </div>
    <source-editor
      :value="value"
      file-name="*.yaml"
      :editor-options="editorOptions"
      @input="onInput"
    />
  </div>
</template>

<script>
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import VulnerabilityFileContentViewer from 'ee/vulnerabilities/components/vulnerability_file_content_viewer.vue';
import BlobHeader from '~/blob/components/blob_header.vue';
import { __, s__ } from '~/locale';
import markMultipleLines from '~/vue_shared/components/source_viewer/plugins/mark_multiple_lines';
import { highlightContent } from '~/highlight_js';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  updateCodeBlocks,
  updateLinesToMarker,
} from 'ee/vue_shared/components/code_flow/utils/utils';

export default {
  name: 'CodeFlowFileViewer',
  components: {
    BlobHeader,
    VulnerabilityFileContentViewer,
    GlButton,
    GlSprintf,
    GlAlert,
  },
  props: {
    hlInfo: {
      type: Array,
      required: false,
      default: () => [],
    },
    blobInfo: {
      type: Object,
      required: true,
      default: () => {},
    },
    filePath: {
      type: String,
      required: true,
      default: undefined,
    },
    branchRef: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      loadingError: false,
      codeBlocks: [],
      linesToMarker: {},
      expanded: true,
      highlightedContent: '',
      blobContent: '',
    };
  },
  computed: {
    userColorScheme() {
      return gon.user_color_scheme;
    },
    totalLines() {
      return this.content?.split('\n').length;
    },
    labelToggleFile() {
      return this.expanded ? __('Hide file contents') : __('Show file contents');
    },
    collapseIcon() {
      return this.expanded ? 'chevron-down' : 'chevron-right';
    },
    isHighlighted() {
      return Boolean(this.highlightedContent);
    },
    content() {
      return this.highlightedContent || this.blobContent;
    },
  },
  created() {
    this.getContent();
    this.mergeCodeBlocks(this.hlInfo);
  },
  methods: {
    getContent() {
      if (!this.blobInfo || isEmpty(this.blobInfo)) {
        this.loadingError = true;
        return;
      }
      const { rawTextBlob, language } = this.blobInfo;
      const plugins = [(result) => markMultipleLines(result, this.linesToMarker)];
      highlightContent(language, rawTextBlob, plugins)
        .then((res) => {
          // res is undefined when the file language is not recognized.
          // we need to mark the step in the viewer even if the language is not recognized.
          if (!res) {
            const markResult = { value: rawTextBlob };
            markMultipleLines(markResult, this.linesToMarker);
            this.highlightedContent = markResult.value;
          } else {
            this.highlightedContent = res;
          }
          this.$emit('codeFlowFileLoaded');
        })
        .catch((error) => {
          Sentry.captureException(error);
        });
      this.blobContent = rawTextBlob;
    },
    mergeCodeBlocks(codeBlocks) {
      const newCodeBlocks = updateCodeBlocks(codeBlocks);
      this.codeBlocks = newCodeBlocks;
      this.linesToMarker = updateLinesToMarker(newCodeBlocks);
    },
    handleToggleFile() {
      this.expanded = !this.expanded;
    },
    handleExpandLines(index) {
      if (index === 0) {
        // expand until line 1
        this.codeBlocks[index].blockStartLine = 1;
      } else if (index === this.codeBlocks.length) {
        // expand until total lines
        this.codeBlocks[this.codeBlocks.length - 1].blockEndLine = this.totalLines;
      } else {
        // expand in-between lines
        this.codeBlocks[index].blockStartLine = this.codeBlocks[index - 1].blockEndLine;
      }
      this.mergeCodeBlocks(this.codeBlocks);
    },
    getExpandedIcon(index) {
      return index !== 0 ? 'expand' : 'expand-up';
    },
    isEndOfCodeBlock(index) {
      return (
        index === this.codeBlocks.length - 1 &&
        this.codeBlocks[index].blockEndLine !== this.totalLines
      );
    },
  },
  i18n: {
    vulnerabilityNotFound: s__('Vulnerability|%{file} was not found in commit %{ref}'),
    expandAllLines: __('Expand all lines'),
  },
};
</script>

<template>
  <div class="file-holder">
    <gl-alert v-if="loadingError" :dismissible="false" variant="warning">
      <gl-sprintf :message="$options.i18n.vulnerabilityNotFound">
        <template #file>
          <code>{{ filePath }}</code>
        </template>
        <template #ref>
          <code>{{ branchRef }}</code>
        </template>
      </gl-sprintf>
    </gl-alert>

    <template v-else>
      <blob-header :blob="blobInfo" :show-blob-size="false" :hide-default-actions="true">
        <template #prepend>
          <gl-button
            class="gl-mr-2"
            category="tertiary"
            size="small"
            :icon="collapseIcon"
            :aria-label="labelToggleFile"
            data-testid="collapse-file"
            @click="handleToggleFile"
          />
        </template>
      </blob-header>

      <div
        v-if="expanded"
        class="file-content code js-syntax-highlight blob-content blob-viewer gl-flex gl-w-full gl-flex-col gl-overflow-auto"
        :class="userColorScheme"
        data-type="simple"
      >
        <div v-for="(highlightSectionInfo, index) in codeBlocks" :key="index">
          <div
            v-if="highlightSectionInfo.blockStartLine !== 1"
            class="expansion-line gl-bg-gray-50 gl-p-1"
          >
            <gl-button
              :title="$options.i18n.expandAllLines"
              :aria-label="$options.i18n.expandAllLines"
              :icon="getExpandedIcon(index)"
              category="tertiary"
              size="small"
              class="mark-multiple-line-expand-button gl-border-0"
              @click="handleExpandLines(index)"
            />
          </div>

          <vulnerability-file-content-viewer
            class="gl-border-none"
            :is-highlighted="isHighlighted"
            :content="content"
            :start-line="highlightSectionInfo.blockStartLine"
            :end-line="highlightSectionInfo.blockEndLine"
            :highlight-info="highlightSectionInfo.highlightInfo"
            @codeFlowFileLoaded="$emit('codeFlowFileLoaded')"
          />

          <div v-if="isEndOfCodeBlock(index)" class="expansion-line gl-bg-gray-50 gl-p-1">
            <gl-button
              :title="$options.i18n.expandAllLines"
              :aria-label="$options.i18n.expandAllLines"
              icon="expand-down"
              category="tertiary"
              size="small"
              class="mark-multiple-line-expand-button gl-border-0"
              @click="handleExpandLines(codeBlocks.length)"
            />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

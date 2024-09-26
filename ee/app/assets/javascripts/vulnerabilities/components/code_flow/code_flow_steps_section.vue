<script>
import { GlBadge, GlButton, GlButtonGroup, GlCollapse, GlLink, GlPopover } from '@gitlab/ui';
import { flattenDeep } from 'lodash';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'CodeFlowStepsSection',
  components: {
    GlPopover,
    GlButton,
    GlButtonGroup,
    GlCollapse,
    GlBadge,
    GlLink,
  },
  directives: {
    SafeHtml,
  },
  props: {
    description: {
      type: String,
      required: false,
      default: null,
    },
    descriptionHtml: {
      type: String,
      required: false,
      default: null,
    },
    details: {
      type: Object,
      required: true,
    },
    rawTextBlobs: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      stepsExpanded: [],
      selectedStepNumber: 1,
      selectedVulnerability: this.details?.items[0][0],
    };
  },
  computed: {
    vulnerabilityFlowDetails() {
      const groupedItems = this.details.items[0].reduce((acc, item, index) => {
        const { fileName } = item.fileLocation;
        if (!acc[fileName]) {
          acc[fileName] = [];
        }
        const fileDescription = this.getDescription(
          this.rawTextBlobs[item.fileLocation.fileName],
          item.fileLocation.lineStart - 1,
        );

        acc[fileName].push({
          ...item,
          nodeType: item.nodeType.toLowerCase(),
          stepNumber: index + 1,
          rawTextBlob: this.rawTextBlobs[item.fileLocation.fileName],
          fileDescription,
        });
        return acc;
      }, {});
      const vulnerabilityFlow = [{ items: Object.values(groupedItems) }];
      return vulnerabilityFlow[0].items;
    },
    numOfSteps() {
      return this.details.items[0].length;
    },
    numOfFiles() {
      return this.vulnerabilityFlowDetails.length;
    },
    stepsHeader() {
      return sprintf(__('%{numOfSteps} steps across %{numOfFiles} files'), {
        numOfSteps: this.numOfSteps,
        numOfFiles: this.numOfFiles,
      });
    },
  },
  mounted() {
    // Use renderGFM() to add syntax highlighting to the markdown.
    renderGFM(this.$refs.markdownContent);
    this.stepsExpanded = Array(this.vulnerabilityFlowDetails.length).fill(true);
  },
  methods: {
    openFileSteps(index) {
      const copyStepsExpanded = [...this.stepsExpanded];
      copyStepsExpanded[index] = !this.stepsExpanded[index];
      this.stepsExpanded = copyStepsExpanded;
    },
    getPathIcon(index) {
      return this.stepsExpanded[index] ? 'chevron-down' : 'chevron-right';
    },
    getBoldFileName(filepath) {
      const parts = filepath.split('/');
      const filename = parts[parts.length - 1];
      return filepath.replace(filename, `<b>${filename}</b>`);
    },
    selectStep(vulnerabilityItem) {
      this.selectedStepNumber = vulnerabilityItem.stepNumber;
      this.selectedVulnerability = vulnerabilityItem;
      this.markdownBlobData();
      this.scrollToSpecificCodeFlow();
    },
    markdownRowContent() {
      // Highlights the selected markdown row content
      const elements = document.querySelectorAll('[id^="TEXT-MARKER"]');
      elements.forEach((el) => {
        el.classList.remove('selected-inline-section-marker');
      });

      // Examples of ID: 'TEXT-MARKER1,2-L8', 'TEXT-MARKER3-L7'
      const element = document.querySelectorAll(
        `[id^="TEXT-MARKER"][id*="${this.selectedStepNumber}-L"], [id^="TEXT-MARKER"][id*=",${this.selectedStepNumber}-L"], [id^="TEXT-MARKER"][id*="${this.selectedStepNumber},"][id*="-L"]`,
      );
      if (element) {
        element.forEach((el) => el.classList.add('selected-inline-section-marker'));
      }
    },
    markdownStepNumber() {
      // Highlights the step number in the markdown
      const elements = document.querySelectorAll('[id^="TEXT-MARKER"]');
      elements.forEach((el) => {
        const spans = el.querySelectorAll('span.inline-item-mark');
        spans.forEach((span) => {
          span.classList.remove('selected-inline-item-mark');
        });
      });
      const element = document.querySelector(`[id^="TEXT-SPAN-MARKER${this.selectedStepNumber}"]`);
      if (element) {
        element.classList.add('selected-inline-item-mark', 'gs');
      }
    },
    markdownRowNumber() {
      // Highlights the row number in the markdown
      const elements = document.querySelectorAll('[id^="NUM-MARKER"]');
      elements.forEach((el) => {
        el.classList.remove('selected-inline-number-mark');
        el.classList.add('unselected-inline-number-mark');
      });

      // Examples of ID: 'NUM-MARKER1,2-L8', 'NUM-MARKER3-L7'
      const element = document.querySelector(
        `[id^="NUM-MARKER"][id*="${this.selectedStepNumber}-L"], [id^="NUM-MARKER"][id*=",${this.selectedStepNumber}-L"], [id^="NUM-MARKER"][id*="${this.selectedStepNumber},"][id*="-L"]`,
      );
      if (element) {
        element.classList.add('selected-inline-number-mark');
        element.classList.remove('unselected-inline-number-mark');
      }
    },
    markdownBlobData() {
      this.markdownRowContent();
      this.markdownStepNumber();
      this.markdownRowNumber();
    },
    getNextIndex(isNext) {
      return isNext ? this.selectedStepNumber + 1 : this.selectedStepNumber - 1;
    },
    isOutOfRange(isNext) {
      const calculation = this.getNextIndex(isNext);
      return calculation > this.numOfSteps || calculation <= 0;
    },
    changeSelectedVulnerability(isNextVulnerability) {
      if (this.isOutOfRange(isNextVulnerability)) return;
      this.selectedVulnerability = flattenDeep(this.vulnerabilityFlowDetails).find(
        (item) => item.stepNumber === this.getNextIndex(isNextVulnerability),
      );
      this.selectedStepNumber = this.selectedVulnerability.stepNumber;
      this.markdownBlobData();
      this.scrollToSpecificCodeFlow();
    },
    scrollToSpecificCodeFlow() {
      const element = document.querySelector(`[id^=TEXT-MARKER${this.selectedStepNumber}]`);
      if (element) {
        const subScroller = document.querySelector(`[id=code-flows-container]`);
        const subScrollerRect = subScroller.getBoundingClientRect();
        const elementRect = element.getBoundingClientRect();
        const offsetTop = elementRect.top - subScrollerRect.top + subScroller.scrollTop;
        subScroller.scrollTo({
          top: offsetTop - subScroller.clientHeight / 2 + element.clientHeight / 2,
          behavior: 'smooth',
        });
      }
    },
    showNodeTypePopover(nodeType) {
      return nodeType === 'source'
        ? this.$options.i18n.sourceNodeTypePopover
        : this.$options.i18n.sinkNodeTypePopover;
    },
    toggleAriaLabel(index) {
      return this.stepsExpanded[index] ? __('Collapse') : __('Expand');
    },
    getDescription(rawTextBlob, startLine) {
      return rawTextBlob?.split(/\r?\n/)[startLine];
    },
  },
  i18n: {
    codeFlowInfoButton: s__('Vulnerability|What is code flow?'),
    codeFlowInfoAnswer: s__(
      "Vulnerability|Code flow helps trace and flag risky data ('tainted data') as it moves through your software. Vulnerabilities are detected by pinpointing how untrusted inputs, like user data or network traffic, are utilized. This technique finds and fixes data handling flaws, securing software from injection and cross-site scripting attacks.",
    ),
    steps: s__('Vulnerability|Steps'),
    sourceNodeTypePopover: s__(
      "Vulnerability|A 'source' refers to untrusted inputs like user data or external data sources. These inputs can introduce security risks into the software system and are monitored to prevent vulnerabilities.",
    ),
    sinkNodeTypePopover: s__(
      "Vulnerability|A 'sink' is where untrusted data is used in a potentially risky way, such as in SQL queries or HTML output. Sink points are monitored to prevent security vulnerabilities in the software.",
    ),
  },
};
</script>

<template>
  <div class="gl-z-0 gl-flex gl-w-4/10 gl-flex-col gl-overflow-auto gl-pl-2 gl-pr-2">
    <div>
      <div class="gl-flex gl-justify-between gl-pt-2">
        <div>
          <div class="item-title gl-text-lg">{{ $options.i18n.steps }}</div>
          <div class="gl-pt-2" data-testid="steps-header">{{ stepsHeader }}</div>
        </div>
        <gl-button-group>
          <gl-button
            icon="chevron-up"
            :aria-label="__(`Previous step`)"
            :disabled="isOutOfRange(false)"
            @click="changeSelectedVulnerability(false)"
          />
          <gl-button
            icon="chevron-down"
            :aria-label="__(`Next step`)"
            :disabled="isOutOfRange(true)"
            @click="changeSelectedVulnerability(true)"
          />
        </gl-button-group>
      </div>
      <div class="gl-ml-4 gl-pt-3">
        <div
          v-for="(vulnerabilityFlow, index) in vulnerabilityFlowDetails"
          :key="index"
          class="-gl-ml-4"
          :data-testid="`file-steps-${index}`"
        >
          <gl-button
            :icon="getPathIcon(index)"
            category="tertiary"
            :aria-label="toggleAriaLabel(index)"
            @click="openFileSteps(index)"
          />
          <span v-safe-html="getBoldFileName(vulnerabilityFlow[0].fileLocation.fileName)"></span>
          <gl-collapse class="gl-mt-2 gl-pl-6" :visible="!!stepsExpanded[index]">
            <gl-link
              v-for="(vulnerabilityItem, i) in vulnerabilityFlow"
              :key="i"
              class="align-content-center gl-flex gl-justify-between !gl-rounded-base gl-pb-2 gl-pl-2 gl-pr-2 gl-pt-2 !gl-text-inherit !gl-no-underline"
              :class="{
                'gl-rounded-base gl-bg-blue-50':
                  selectedStepNumber === vulnerabilityItem.stepNumber,
              }"
              :data-testid="`step-row-${i}`"
              @click="selectStep(vulnerabilityItem)"
            >
              <gl-badge
                class="gl-mr-3 gl-h-6 gl-w-6 gl-rounded-base gl-pl-4 gl-pr-4"
                :class="{
                  '!gl-bg-blue-500 !gl-text-white':
                    selectedStepNumber === vulnerabilityItem.stepNumber,
                }"
                size="lg"
                variant="muted"
              >
                <strong v-if="selectedStepNumber === vulnerabilityItem.stepNumber">{{
                  vulnerabilityItem.stepNumber
                }}</strong>
                <span v-else>{{ vulnerabilityItem.stepNumber }}</span>
              </gl-badge>
              <span
                class="align-content-center gl-mr-auto gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
              >
                <gl-badge
                  v-if="['source', 'sink'].includes(vulnerabilityItem.nodeType)"
                  :id="vulnerabilityItem.nodeType"
                  :data-testid="vulnerabilityItem.nodeType"
                  class="gl-mr-3 gl-pl-4 gl-pr-4"
                  size="md"
                  variant="muted"
                >
                  {{ vulnerabilityItem.nodeType }}
                </gl-badge>
                <gl-popover
                  triggers="hover focus"
                  placement="top"
                  :target="vulnerabilityItem.nodeType"
                  :content="showNodeTypePopover(vulnerabilityItem.nodeType)"
                  :show="false"
                />

                {{ vulnerabilityItem.fileDescription }}
              </span>
              <span class="align-content-center gl-pr-3 gl-text-gray-600">{{
                vulnerabilityItem.fileLocation.lineStart
              }}</span>
            </gl-link>
          </gl-collapse>
        </div>
      </div>
    </div>
  </div>
</template>

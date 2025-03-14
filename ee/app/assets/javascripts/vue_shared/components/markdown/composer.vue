<script>
import { v4 as uuidv4 } from 'uuid';
import { GlDisclosureDropdown, GlButton, GlFormInput, GlFormGroup, GlIcon } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { __ } from '~/locale';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { updateText } from '~/lib/utils/text_markdown';
import { CONTENT_EDITOR_PASTE } from '~/vue_shared/constants';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';

export default {
  name: 'MarkdownComposer',
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      composer: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: this.userId,
            htmlResponse: true,
            clientSubscriptionId: this.composerSubscriptionID,
          };
        },
        result({ data }) {
          if (!data.aiCompletionResponse) return;

          const { content, contentHtml } = data.aiCompletionResponse;

          this.aiContentPreview = content;
          this.aiContentPreviewHTML = contentHtml;
          this.aiContentPreviewLoading = false;
        },
      },
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      summarizeChanges: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: this.userId,
            htmlResponse: true,
            clientSubscriptionId: this.summarizeSubscriptionID,
          };
        },
        result({ data: { aiCompletionResponse } }) {
          if (aiCompletionResponse) {
            const { content } = aiCompletionResponse;

            if (this.textarea) {
              updateText({
                textArea: this.textarea,
                tag: content,
                cursorOffset: 0,
                wrap: false,
              });
            } else {
              markdownEditorEventHub.$emit(CONTENT_EDITOR_PASTE, content);
            }
          }
        },
      },
    },
  },
  directives: { SafeHtml },
  components: { GlDisclosureDropdown, GlButton, GlFormInput, GlFormGroup, GlIcon },
  mixins: [InternalEvents.mixin()],
  inject: ['projectId', 'sourceBranch', 'targetBranch'],
  props: {
    markdown: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      showComposerPrompt: false,
      userPrompt: '',
      aiContentPreviewLoading: false,
      aiContentPreview: null,
      aiContentPreviewHTML: null,
      cursorLocation: 0,
      top: 0,
    };
  },
  computed: {
    resourceId() {
      return convertToGraphQLId(TYPENAME_PROJECT, this.projectId);
    },
    userId() {
      return convertToGraphQLId(TYPENAME_USER, gon.current_user_id);
    },
    dropdownItems() {
      return [
        {
          text: __('Insert code change summary'),
          action: () => {
            this.trackEvent('click_summarize_code_changes');

            this.$apollo.mutate({
              mutation: aiActionMutation,
              variables: {
                input: {
                  summarizeNewMergeRequest: {
                    resourceId: this.resourceId,
                    sourceProjectId: this.projectId,
                    sourceBranch: this.sourceBranch,
                    targetBranch: this.targetBranch,
                  },
                  clientSubscriptionId: this.summarizeSubscriptionID,
                },
              },
            });
          },
        },
        {
          text: __('Write with GitLab Duo'),
          action: () => {
            this.showComposerPrompt = true;
          },
        },
      ];
    },
    cursorText() {
      return this.markdown.substring(0, this.cursorLocation);
    },
    cursorAfterText() {
      return this.markdown.substring(this.cursorLocation);
    },
    composerSubscriptionID() {
      return `composer-${uuidv4()}`;
    },
    summarizeSubscriptionID() {
      return uuidv4();
    },
  },
  mounted() {
    this.textarea = this.$el.querySelector('textarea');

    if (this.textarea) {
      this.textarea.addEventListener('mouseup', this.onKeyUp);
      this.textarea.addEventListener('keyup', this.onKeyUp);
      this.textarea.addEventListener('scroll', this.onScroll);
    }
  },
  beforeDestroy() {
    if (this.textarea) {
      this.textarea.removeEventListener('mouseup', this.onKeyUp);
      this.textarea.removeEventListener('keyup', this.onKeyUp);
      this.textarea.removeEventListener('scroll', this.onScroll);
    }
  },
  methods: {
    onKeyUp() {
      this.cursorLocation = this.textarea.selectionStart;
      this.$nextTick(() => {
        this.top = this.$refs.text.offsetTop - 1;
        this.onScroll();
      });
    },
    onScroll() {
      this.$refs.textContainer.scrollTo(0, this.textarea.scrollTop);
    },
    submitComposer() {
      let description = this.markdown || '';
      description = `${description.slice(
        0,
        this.textarea?.selectionStart || 0,
      )}<selected-text>${description.slice(
        this.textarea?.selectionStart || 0,
        this.textarea?.selectionEnd || 0,
      )}</selected-text>${description.slice(this.textarea?.selectionEnd || 0)}`;

      this.aiContentPreviewLoading = true;

      this.$apollo.mutate({
        mutation: aiActionMutation,
        variables: {
          input: {
            descriptionComposer: {
              resourceId: this.resourceId,
              sourceProjectId: this.projectId,
              sourceBranch: this.sourceBranch,
              targetBranch: this.targetBranch,
              description,
              title: document.querySelector('.js-issuable-title')?.value ?? '',
              userPrompt: this.userPrompt || '',
            },
            clientSubscriptionId: this.composerSubscriptionID,
          },
        },
      });
    },
    insertAiContent() {
      updateText({
        textArea: this.textarea,
        tag: this.aiContentPreview,
        cursorOffset: 0,
        wrap: false,
        replaceText: true,
      });
    },
    onDropdownHidden() {
      this.aiContentPreview = null;
      this.aiContentPreviewHTML = null;
      this.showComposerPrompt = false;
      this.userPrompt = '';
    },
  },
};
</script>

<template>
  <div class="gl-relative gl-overflow-x-hidden">
    <slot></slot>
    <div
      ref="textContainer"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-[-50px] gl-top-[-2px] gl-overflow-auto gl-border-2 gl-border-solid gl-border-transparent gl-py-[10px] gl-pl-7 gl-pr-[66px]"
    >
      <!-- prettier-ignore -->
      <div 
          class="gfm-input-text markdown-area gl-invisible !gl-font-monospace gl-whitespace-pre-wrap gl-border-0 gl-p-0 !gl-max-h-fit"
          style="word-wrap: break-word">{{ cursorText }}<span ref="text">|</span>{{ cursorAfterText }}</div>
      <gl-disclosure-dropdown
        v-show="top !== 0"
        class="gl-absolute gl-left-2 gl-top-0 gl-z-4"
        :class="{ 'composer-prompt-visible': showComposerPrompt }"
        icon="tanuki-ai"
        no-caret
        size="small"
        category="tertiary"
        placement="right-start"
        :style="{ top: `${top}px` }"
        :items="dropdownItems"
        :auto-close="false"
        positioning-strategy="fixed"
        fluid-width
        @hidden="onDropdownHidden"
      >
        <template v-if="showComposerPrompt">
          <div
            class="gl-flex gl-min-h-5 gl-items-center gl-border-b-1 gl-border-b-dropdown-divider gl-px-4 gl-py-3 gl-border-b-solid"
          >
            <div class="gl-grow gl-pr-2 gl-text-sm gl-font-bold gl-text-strong">
              <gl-icon name="tanuki-ai" />
              {{ __('Write with GitLab Duo') }}
            </div>
          </div>
          <div
            class="gl-w-[450px] gl-max-w-[80vw] gl-p-3"
            :class="{ 'gl-pt-0': aiContentPreviewHTML }"
          >
            <div
              v-if="aiContentPreviewHTML"
              v-safe-html="aiContentPreviewHTML"
              class="md gl-mb-4 gl-max-h-[200px] gl-overflow-y-auto gl-border-gray-100 gl-px-4 gl-pb-4 gl-pt-4 gl-border-b-solid"
            ></div>
            <div>
              <gl-form-group label="Prompt" label-for="composer-user-prompt">
                <gl-form-input
                  id="composer-user-prompt"
                  v-model="userPrompt"
                  :placeholder="__('Enter a prompt')"
                  autocomplete="off"
                  autofocus
                  data-testid="composer-user-prompt"
                  @keydown.enter.prevent.stop="submitComposer"
                />
              </gl-form-group>
              <div class="gl-flex gl-justify-end gl-gap-3">
                <gl-button
                  v-if="aiContentPreview"
                  data-testid="composer-insert"
                  @click="insertAiContent"
                  >{{ __('Insert') }}</gl-button
                >
                <gl-button
                  variant="confirm"
                  :loading="aiContentPreviewLoading"
                  data-testid="composer-submit"
                  @click="submitComposer"
                >
                  <template v-if="aiContentPreview">{{ __('Regenerate') }}</template>
                  <template v-else>{{ __('Generate') }}</template>
                </gl-button>
              </div>
            </div>
          </div>
        </template>
      </gl-disclosure-dropdown>
    </div>
  </div>
</template>

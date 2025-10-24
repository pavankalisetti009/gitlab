<script>
import { GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getDraft, clearDraft, updateDraft } from '~/lib/utils/autosave';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { detectAndConfirmSensitiveTokens } from '~/lib/utils/secret_detection';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { trackSavedUsingEditor } from '~/vue_shared/components/markdown/tracking';
import createNoteMutation from '../graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';

export default {
  name: 'ComplianceViolationCommentForm',
  i18n: {
    addCommentText: s__('ComplianceViolation|Add a comment'),
    confirmText: __('Are you sure you want to cancel creating this comment?'),
    continueEditingText: __('Continue editing'),
    createCommentError: s__(
      'ComplianceViolation|Something went wrong when creating the comment. Please try again.',
    ),
    discardText: __('Discard changes'),
    placeholderText: __('Write a comment or drag your files here…'),
  },
  components: {
    GlButton,
    MarkdownEditor,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    isSubmitting: {
      type: Boolean,
      required: false,
      default: false,
    },
    uploadsPath: {
      type: String,
      required: false,
      default: '',
    },
    markdownPreviewPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      commentText: '',
      isCreatingComment: false,
    };
  },
  computed: {
    formFieldProps() {
      return {
        'aria-label': this.$options.i18n.addCommentText,
        placeholder: this.$options.i18n.placeholderText,
        id: 'compliance-violation-add-comment',
        name: 'compliance-violation-add-comment',
      };
    },
    markdownDocsPath() {
      return helpPagePath('user/markdown');
    },
    canSubmit() {
      return this.commentText.trim().length > 0 && !this.isCreatingComment;
    },
    autosaveKey() {
      return `compliance-violation-comment-${this.violationId}`;
    },
  },
  created() {
    this.commentText = getDraft(this.autosaveKey) || '';
  },
  methods: {
    setCommentText(newText) {
      if (!this.isSubmitting && !this.isCreatingComment) {
        this.commentText = newText;
        updateDraft(this.autosaveKey, this.commentText);
      }
    },
    async cancelEditing() {
      if (this.commentText) {
        const confirmed = await confirmAction(this.$options.i18n.confirmText, {
          primaryBtnText: this.$options.i18n.discardText,
          cancelBtnText: this.$options.i18n.continueEditingText,
          primaryBtnVariant: 'danger',
        });

        if (!confirmed) {
          return;
        }
      }

      this.commentText = '';
      clearDraft(this.autosaveKey);
      this.$emit('cancelEditing');
    },
    updateCache(cache, { data }) {
      const variables = { id: this.violationId };
      const sourceData = cache.readQuery({
        query: complianceViolationQuery,
        variables,
      });

      if (!sourceData?.projectComplianceViolation) {
        return;
      }

      const newNote = data.createNote.note;
      const existingNotes = sourceData.projectComplianceViolation.notes?.nodes || [];

      // Add the new note to the end of the notes list
      const updatedData = {
        ...sourceData,
        projectComplianceViolation: {
          ...sourceData.projectComplianceViolation,
          notes: {
            ...sourceData.projectComplianceViolation.notes,
            nodes: [...existingNotes, newNote],
          },
        },
      };

      cache.writeQuery({
        query: complianceViolationQuery,
        variables,
        data: updatedData,
      });
    },
    async submitForm() {
      if (!this.canSubmit) {
        return;
      }

      const confirmSubmit = await detectAndConfirmSensitiveTokens({ content: this.commentText });
      if (!confirmSubmit) {
        return;
      }

      this.isCreatingComment = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createNoteMutation,
          variables: {
            input: {
              noteableId: this.violationId,
              body: this.commentText,
            },
          },
          update: this.updateCache,
        });

        if (data?.createNote?.errors?.length > 0) {
          throw new Error(data.createNote.errors.join(', '));
        }

        // Track editor usage
        if (this.$refs.markdownEditor) {
          trackSavedUsingEditor(
            this.$refs.markdownEditor.isContentEditorActive,
            'ComplianceViolation_Comment',
          );
        }

        // Clear the form and draft
        this.commentText = '';
        clearDraft(this.autosaveKey);

        // Emit success event with the created note
        this.$emit('commentCreated', data.createNote.note);
      } catch (error) {
        this.$emit('error', this.$options.i18n.createCommentError);
      } finally {
        this.isCreatingComment = false;
      }
    },
  },
};
</script>

<template>
  <form class="common-note-form gfm-form js-main-target-form new-note">
    <div class="timeline-discussion-body !gl-overflow-visible">
      <div class="note-body !gl-overflow-visible !gl-p-0">
        <markdown-editor
          ref="markdownEditor"
          :value="commentText"
          :enable-content-editor="true"
          :render-markdown-path="markdownPreviewPath"
          :uploads-path="uploadsPath"
          :markdown-docs-path="markdownDocsPath"
          :form-field-props="formFieldProps"
          :autofocus="true"
          @input="setCommentText"
          @keydown.meta.enter="submitForm"
          @keydown.ctrl.enter="submitForm"
          @keydown.esc.stop="cancelEditing"
        />
      </div>
    </div>
    <div class="note-form-actions gl-flex gl-gap-3">
      <gl-button
        category="primary"
        variant="confirm"
        data-testid="comment-button"
        :disabled="!canSubmit"
        :loading="isCreatingComment"
        @click="submitForm"
      >
        {{ __('Comment') }}
      </gl-button>
      <gl-button data-testid="cancel-button" category="primary" @click="cancelEditing">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </form>
</template>

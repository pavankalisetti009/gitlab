<script>
import { __, s__ } from '~/locale';
import updateNoteMutation from '../graphql/mutations/update_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import BaseCommentForm from './base_comment_form.vue';

export default {
  name: 'EditCommentForm',
  components: {
    BaseCommentForm,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    noteId: {
      type: String,
      required: true,
    },
    numericNoteId: {
      type: Number,
      required: true,
    },
    initialValue: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isUpdating: false,
      submitSuccess: false,
    };
  },
  computed: {
    formFieldProps() {
      return {
        'aria-label': __('Edit comment'),
        placeholder: s__('ComplianceViolation|Write a comment or drag your files here…'),
        id: `compliance-violation-edit-comment-${this.numericNoteId}`,
        name: `compliance-violation-edit-comment-${this.numericNoteId}`,
      };
    },
    autosaveKey() {
      return `compliance-violation-edit-comment-${this.numericNoteId}`;
    },
  },
  methods: {
    async updateComment(commentText) {
      this.isUpdating = true;
      this.submitSuccess = false;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateNoteMutation,
          variables: {
            input: {
              id: this.noteId,
              body: commentText,
            },
          },
          update: this.updateCache,
        });

        if (data?.updateNote?.errors?.length > 0) {
          this.$emit('error', this.$options.i18n.updateCommentError);
          return;
        }

        this.$emit('commentUpdated', data.updateNote.note);

        this.submitSuccess = true;
      } catch (error) {
        this.$emit('error', this.$options.i18n.updateCommentError);
      } finally {
        this.isUpdating = false;
      }
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

      const updatedNote = data.updateNote.note;
      const existingNotes = sourceData.projectComplianceViolation.notes?.nodes || [];

      const updatedNotes = existingNotes.map((note) =>
        note.id === updatedNote.id ? updatedNote : note,
      );

      const updatedData = {
        ...sourceData,
        projectComplianceViolation: {
          ...sourceData.projectComplianceViolation,
          notes: {
            ...sourceData.projectComplianceViolation.notes,
            nodes: updatedNotes,
          },
        },
      };

      cache.writeQuery({
        query: complianceViolationQuery,
        variables,
        data: updatedData,
      });
    },
  },
  i18n: {
    updateCommentError: s__(
      'ComplianceViolation|Something went wrong when updating the comment. Please try again.',
    ),
  },
};
</script>

<template>
  <base-comment-form
    :initial-value="initialValue"
    :autosave-key="autosaveKey"
    :form-field-props="formFieldProps"
    :submit-button-text="__('Save comment')"
    :confirm-cancel-text="__('Are you sure you want to cancel editing this comment?')"
    :is-submitting="isUpdating"
    :should-clear-form="submitSuccess"
    @submit="updateComment"
    @cancel="$emit('cancel')"
  />
</template>

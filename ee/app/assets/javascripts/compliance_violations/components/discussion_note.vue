<script>
import {
  GlAvatarLink,
  GlAvatar,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlDisclosureDropdownGroup,
  GlTooltipDirective,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getLocationHash } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import toast from '~/vue_shared/plugins/global_toast';
import SafeHtml from '~/vue_shared/directives/safe_html';
import NoteHeader from '~/notes/components/note_header.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import EditedAt from '~/issues/show/components/edited.vue';
import destroyComplianceViolationNoteMutation from '../graphql/mutations/destroy_compliance_violation_note.mutation.graphql';
import EditCommentForm from './edit_comment_form.vue';

export default {
  name: 'DiscussionNote',
  components: {
    EditCommentForm,
    EditedAt,
    GlAvatar,
    GlAvatarLink,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlDisclosureDropdownGroup,
    NoteHeader,
    TimelineEntryItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    note: {
      type: Object,
      required: true,
    },
    violationId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isDeleting: false,
      isEditing: false,
    };
  },
  computed: {
    targetNoteHash() {
      return getLocationHash();
    },
    noteAnchorId() {
      return `note_${this.noteId}`;
    },
    isTargetNote() {
      return this.targetNoteHash === this.noteAnchorId;
    },
    noteId() {
      return getIdFromGraphQLId(this.note.id);
    },
    author() {
      return this.note.author || {};
    },
    authorId() {
      return getIdFromGraphQLId(this.author.id);
    },
    noteUrl() {
      return `#${this.noteAnchorId}`;
    },
    fullNoteUrl() {
      const currentUrl = window.location.href.split('#')[0];
      return `${currentUrl}${this.noteUrl}`;
    },
    entryClass() {
      return {
        'note note-wrapper note-comment': true,
        target: this.isTargetNote,
      };
    },
  },
  methods: {
    copyNoteLink() {
      // eslint-disable-next-line no-restricted-properties
      navigator.clipboard.writeText(this.fullNoteUrl);
      toast(__('Link copied to clipboard.'));
      this.$refs.dropdown.close();
    },
    async deleteNote() {
      if (this.isDeleting) return;

      this.isDeleting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: destroyComplianceViolationNoteMutation,
          variables: {
            input: {
              id: this.note.id,
            },
          },
        });

        if (data?.destroyNote?.errors?.length > 0) {
          toast(this.$options.i18n.deleteCommentError);
          return;
        }

        this.$emit('noteDeleted', this.note.id);
        toast(s__('ComplianceViolation|Comment deleted successfully.'));
      } catch (error) {
        toast(this.$options.i18n.deleteCommentError);
      } finally {
        this.isDeleting = false;
        this.$refs.dropdown.close();
      }
    },
    editNote() {
      this.isEditing = true;
    },
    cancelEdit() {
      this.isEditing = false;
    },
    handleCommentUpdated() {
      this.isEditing = false;
    },
    handleEditError(errorMessage) {
      this.$emit('error', errorMessage);
    },
  },
  i18n: {
    moreActionsText: __('More actions'),
    deleteCommentError: s__(
      'ComplianceViolation|Something went wrong when deleting the comment. Please try again.',
    ),
  },
  safeHtmlConfig: {
    ADD_TAGS: ['use'], // to support icon SVGs
  },
};
</script>

<template>
  <timeline-entry-item :id="noteAnchorId" :class="entryClass">
    <div class="timeline-avatar gl-float-left">
      <gl-avatar-link
        :href="author.webUrl"
        :data-user-id="authorId"
        :data-username="author.username"
        class="js-user-link"
      >
        <gl-avatar
          :src="author.avatarUrl"
          :entity-name="author.username"
          :alt="author.name"
          :size="32"
        />
      </gl-avatar-link>
    </div>
    <div class="timeline-content">
      <div data-testid="note-wrapper">
        <div class="note-header">
          <note-header
            :author="author"
            :created-at="note.createdAt"
            :note-id="noteId"
            :note-url="noteUrl"
          />
          <div v-if="!isEditing" class="note-actions gl-ml-auto gl-flex gl-gap-2">
            <gl-button
              v-if="glFeatures.complianceViolationCommentsUi"
              v-gl-tooltip
              icon="pencil"
              category="tertiary"
              size="small"
              :title="__('Edit comment')"
              :aria-label="__('Edit comment')"
              data-testid="edit-note-button"
              @click="editNote"
            />
            <gl-disclosure-dropdown
              ref="dropdown"
              v-gl-tooltip
              icon="ellipsis_v"
              text-sr-only
              placement="bottom-end"
              :toggle-text="$options.i18n.moreActionsText"
              :title="$options.i18n.moreActionsText"
              category="tertiary"
              no-caret
              data-testid="note-actions-dropdown"
            >
              <gl-disclosure-dropdown-item data-testid="copy-link-action" @action="copyNoteLink">
                <template #list-item>
                  {{ __('Copy link') }}
                </template>
              </gl-disclosure-dropdown-item>
              <gl-disclosure-dropdown-group bordered>
                <gl-disclosure-dropdown-item
                  data-testid="delete-note-action"
                  variant="danger"
                  :disabled="isDeleting"
                  @action="deleteNote"
                >
                  <template #list-item>
                    {{ __('Delete comment') }}
                  </template>
                </gl-disclosure-dropdown-item>
              </gl-disclosure-dropdown-group>
            </gl-disclosure-dropdown>
          </div>
        </div>
        <div class="note-body" data-testid="discussion-note-body">
          <div v-if="isEditing" class="timeline-discussion-body">
            <edit-comment-form
              :violation-id="violationId"
              :note-id="note.id"
              :numeric-note-id="noteId"
              :initial-value="note.body"
              @commentUpdated="handleCommentUpdated"
              @cancel="cancelEdit"
              @error="handleEditError"
            />
          </div>
          <div v-else class="timeline-discussion-body">
            <div
              v-safe-html:[$options.safeHtmlConfig]="note.bodyHtml"
              class="note-text md"
              data-testid="discussion-note-text"
            ></div>
          </div>
          <edited-at
            v-if="note.lastEditedBy && !isEditing"
            :updated-at="note.lastEditedAt"
            :updated-by-name="note.lastEditedBy.name"
            :updated-by-path="note.lastEditedBy.webPath"
            class="gl-mt-5"
          />
        </div>
      </div>
    </div>
  </timeline-entry-item>
</template>

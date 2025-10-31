import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAvatar, GlAvatarLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { getLocationHash } from '~/lib/utils/url_utility';
import toast from '~/vue_shared/plugins/global_toast';
import NoteHeader from '~/notes/components/note_header.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import EditedAt from '~/issues/show/components/edited.vue';
import DiscussionNote from 'ee/compliance_violations/components/discussion_note.vue';
import EditCommentForm from 'ee/compliance_violations/components/edit_comment_form.vue';
import destroyComplianceViolationNoteMutation from 'ee/compliance_violations/graphql/mutations/destroy_compliance_violation_note.mutation.graphql';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  getLocationHash: jest.fn(),
}));
jest.mock('~/vue_shared/plugins/global_toast');

describe('DiscussionNote', () => {
  let wrapper;

  const mockNote = {
    id: 'gid://gitlab/Note/123',
    author: {
      id: 'gid://gitlab/User/456',
      name: 'John Doe',
      username: 'johndoe',
      avatarUrl: 'https://example.com/avatar.jpg',
      webUrl: 'https://example.com/johndoe',
    },
    body: 'This is a discussion note',
    bodyHtml: '<p>This is a discussion note</p>',
    createdAt: '2023-01-01T00:00:00Z',
    lastEditedAt: null,
    lastEditedBy: null,
  };

  const mockNoteWithEdit = {
    ...mockNote,
    lastEditedAt: '2023-01-02T00:00:00Z',
    lastEditedBy: {
      name: 'Jane Editor',
      webPath: '/jane-editor',
    },
  };

  const mockDeleteNoteSuccess = {
    data: {
      destroyNote: {
        errors: [],
        note: {
          id: mockNote.id,
        },
      },
    },
  };

  const mockDeleteNoteError = {
    data: {
      destroyNote: {
        errors: ['Something went wrong'],
        note: null,
      },
    },
  };

  const createDropdownStub = () => {
    const mockClose = jest.fn();
    return {
      stub: {
        GlDisclosureDropdown: stubComponent(
          {},
          {
            methods: {
              close: mockClose,
            },
          },
        ),
      },
      mockClose,
    };
  };

  const createComponent = ({
    props = {},
    deleteNoteMutationHandler = jest.fn().mockResolvedValue(mockDeleteNoteSuccess),
    stubs = {},
    provide = {},
  } = {}) => {
    const apolloProvider = createMockApollo([
      [destroyComplianceViolationNoteMutation, deleteNoteMutationHandler],
    ]);

    wrapper = shallowMountExtended(DiscussionNote, {
      propsData: {
        note: mockNote,
        violationId: 'gid://gitlab/ComplianceViolation/123',
        ...props,
      },
      apolloProvider,
      stubs,
      provide: {
        glFeatures: {
          complianceViolationCommentsUi: true,
        },
        ...provide,
      },
    });
  };

  const findTimelineEntryItem = () => wrapper.findComponent(TimelineEntryItem);
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);
  const findNoteHeader = () => wrapper.findComponent(NoteHeader);
  const findNoteText = () => wrapper.findByTestId('discussion-note-text');
  const findActionsDropdown = () => wrapper.findByTestId('note-actions-dropdown');
  const findCopyLinkAction = () => wrapper.findByTestId('copy-link-action');
  const findDeleteNoteAction = () => wrapper.findByTestId('delete-note-action');
  const findEditButton = () => wrapper.findByTestId('edit-note-button');
  const findEditedAt = () => wrapper.findComponent(EditedAt);
  const findEditCommentForm = () => wrapper.findComponent(EditCommentForm);

  beforeEach(() => {
    getLocationHash.mockReturnValue('');
    toast.mockClear();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders TimelineEntryItem with correct props', () => {
      const timelineItem = findTimelineEntryItem();

      expect(timelineItem.exists()).toBe(true);
      expect(timelineItem.attributes('id')).toBe('note_123');
      expect(timelineItem.classes()).toContain('note');
      expect(timelineItem.classes()).toContain('note-wrapper');
      expect(timelineItem.classes()).toContain('note-comment');
    });

    it('renders avatar with correct props', () => {
      const avatar = findAvatar();

      expect(avatar.exists()).toBe(true);
      expect(avatar.props()).toMatchObject({
        src: mockNote.author.avatarUrl,
        entityName: mockNote.author.username,
        alt: mockNote.author.name,
        size: 32,
      });
    });

    it('renders avatar link with correct props', () => {
      const avatarLink = findAvatarLink();

      expect(avatarLink.exists()).toBe(true);
      expect(avatarLink.attributes('href')).toBe(mockNote.author.webUrl);
      expect(avatarLink.attributes('data-user-id')).toBe('456');
      expect(avatarLink.attributes('data-username')).toBe(mockNote.author.username);
      expect(avatarLink.classes()).toContain('js-user-link');
    });

    it('renders note header with correct props', () => {
      const noteHeader = findNoteHeader();

      expect(noteHeader.exists()).toBe(true);
      expect(noteHeader.props()).toMatchObject({
        author: mockNote.author,
        createdAt: mockNote.createdAt,
        noteId: 123,
        noteUrl: '#note_123',
      });
    });

    it('renders the correct note', () => {
      expect(findNoteHeader().props('noteId')).toBe(123);
      expect(findNoteHeader().props('noteUrl')).toBe('#note_123');
    });

    it('renders note body with HTML content', () => {
      const noteText = findNoteText();

      expect(noteText.exists()).toBe(true);
      expect(noteText.html()).toContain('<p>This is a discussion note</p>');
      expect(noteText.classes()).toContain('note-text');
      expect(noteText.classes()).toContain('md');
    });

    it('renders actions dropdown with correct props', () => {
      const dropdown = findActionsDropdown();

      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        icon: 'ellipsis_v',
        textSrOnly: true,
        placement: 'bottom-end',
        category: 'tertiary',
        noCaret: true,
      });
      expect(dropdown.attributes('title')).toBe('More actions');
    });

    it('renders copy link action', () => {
      const copyAction = findCopyLinkAction();

      expect(copyAction.exists()).toBe(true);
    });

    it('renders delete note action', () => {
      const deleteAction = findDeleteNoteAction();

      expect(deleteAction.exists()).toBe(true);
      expect(deleteAction.props('variant')).toBe('danger');
    });

    it('renders edit button', () => {
      const editButton = findEditButton();

      expect(editButton.exists()).toBe(true);
      expect(editButton.attributes('title')).toBe('Edit comment');
      expect(editButton.attributes('aria-label')).toBe('Edit comment');
    });

    it('does not render edit comment form initially', () => {
      expect(findEditCommentForm().exists()).toBe(false);
    });

    it('does not render EditedAt component when note has not been edited', () => {
      expect(findEditedAt().exists()).toBe(false);
    });

    it('renders with correct timeline structure', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('note targeting', () => {
    it('applies target class when note is targeted', () => {
      getLocationHash.mockReturnValue('note_123');
      createComponent();

      expect(findTimelineEntryItem().classes()).toContain('target');
    });

    it('does not apply target class when note is not targeted', () => {
      getLocationHash.mockReturnValue('note_456');
      createComponent();

      expect(findTimelineEntryItem().classes()).not.toContain('target');
    });
  });

  describe('copy link functionality', () => {
    beforeEach(() => {
      setWindowLocation('https://example.com/compliance/violations/123');
      jest.spyOn(navigator.clipboard, 'writeText').mockResolvedValue();
    });

    it('copies the correct URL when copy link is clicked', async () => {
      const { stub, mockClose } = createDropdownStub();
      createComponent({ stubs: stub });

      await findCopyLinkAction().vm.$emit('action');

      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
        'https://example.com/compliance/violations/123#note_123',
      );
      expect(toast).toHaveBeenCalledWith('Link copied to clipboard.');
      expect(mockClose).toHaveBeenCalled();
    });
  });

  describe('delete note functionality', () => {
    let deleteNoteMutationHandler;
    let mockClose;

    beforeEach(() => {
      const dropdownStub = createDropdownStub();
      mockClose = dropdownStub.mockClose;
      deleteNoteMutationHandler = jest.fn().mockResolvedValue(mockDeleteNoteSuccess);
      createComponent({
        deleteNoteMutationHandler,
        stubs: dropdownStub.stub,
      });
    });

    it('deletes note successfully', async () => {
      await findDeleteNoteAction().vm.$emit('action');
      await waitForPromises();

      expect(deleteNoteMutationHandler).toHaveBeenCalledTimes(1);
      expect(deleteNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          id: mockNote.id,
        },
      });
      expect(wrapper.emitted('noteDeleted')).toEqual([[mockNote.id]]);
      expect(toast).toHaveBeenCalledWith('Comment deleted successfully.');
      expect(mockClose).toHaveBeenCalled();
    });

    it('handles mutation errors', async () => {
      const errorHandler = jest.fn().mockResolvedValue(mockDeleteNoteError);
      const dropdownStub = createDropdownStub();
      createComponent({
        deleteNoteMutationHandler: errorHandler,
        stubs: dropdownStub.stub,
      });

      await findDeleteNoteAction().vm.$emit('action');
      await waitForPromises();

      expect(errorHandler).toHaveBeenCalledTimes(1);
      expect(errorHandler).toHaveBeenCalledWith({
        input: {
          id: mockNote.id,
        },
      });
      expect(wrapper.emitted('noteDeleted')).toBeUndefined();
      expect(toast).toHaveBeenCalledWith(
        'Something went wrong when deleting the comment. Please try again.',
      );
      expect(dropdownStub.mockClose).toHaveBeenCalled();
    });

    it('handles network errors', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      const dropdownStub = createDropdownStub();
      createComponent({
        deleteNoteMutationHandler: errorHandler,
        stubs: dropdownStub.stub,
      });

      await findDeleteNoteAction().vm.$emit('action');
      await waitForPromises();

      expect(errorHandler).toHaveBeenCalledTimes(1);
      expect(toast).toHaveBeenCalledWith(
        'Something went wrong when deleting the comment. Please try again.',
      );
      expect(dropdownStub.mockClose).toHaveBeenCalled();
    });
  });

  describe('edit comment functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows edit form when edit button is clicked', async () => {
      expect(findNoteText().exists()).toBe(true);
      expect(findEditCommentForm().exists()).toBe(false);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findNoteText().exists()).toBe(false);
      expect(findEditCommentForm().exists()).toBe(true);
    });

    it('hides note actions when in edit mode', async () => {
      expect(findActionsDropdown().exists()).toBe(true);
      expect(findEditButton().exists()).toBe(true);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findActionsDropdown().exists()).toBe(false);
      expect(findEditButton().exists()).toBe(false);
    });

    it('exits edit mode when form emits cancel', async () => {
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('cancel');
      await waitForPromises();

      expect(findNoteText().exists()).toBe(true);
      expect(findActionsDropdown().exists()).toBe(true);
    });

    it('exits edit mode when comment is updated', async () => {
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('commentUpdated');
      await waitForPromises();

      expect(findNoteText().exists()).toBe(true);
      expect(findActionsDropdown().exists()).toBe(true);
    });

    it('emits error event when edit form emits error', async () => {
      const errorMessage = 'Failed to update form';
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('error', errorMessage);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([[errorMessage]]);
    });
  });

  describe('edited note display', () => {
    it('renders EditedAt component when note has been edited', () => {
      createComponent({
        props: {
          note: mockNoteWithEdit,
        },
      });

      const editedAt = findEditedAt();
      expect(editedAt.exists()).toBe(true);
    });

    it('does not render EditedAt component when in edit mode', async () => {
      createComponent({
        props: {
          note: mockNoteWithEdit,
        },
      });

      expect(findEditedAt().exists()).toBe(true);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findEditedAt().exists()).toBe(false);
    });
  });

  describe('empty content handling', () => {
    it('renders when bodyHtml is empty', () => {
      createComponent({
        props: {
          note: {
            ...mockNote,
            bodyHtml: '',
          },
        },
      });

      const noteText = findNoteText();
      expect(noteText.exists()).toBe(true);
      expect(noteText.text()).toBe('');
    });
  });

  describe('feature flag: complianceViolationCommentsUi', () => {
    describe('when feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              complianceViolationCommentsUi: true,
            },
          },
        });
      });

      it('renders edit button', () => {
        const editButton = findEditButton();

        expect(editButton.exists()).toBe(true);
        expect(editButton.attributes('title')).toBe('Edit comment');
        expect(editButton.attributes('aria-label')).toBe('Edit comment');
      });
    });

    describe('when feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              complianceViolationCommentsUi: false,
            },
          },
        });
      });

      it('does not render edit button', () => {
        const editButton = findEditButton();

        expect(editButton.exists()).toBe(false);
      });

      it('still renders other note actions', () => {
        expect(findActionsDropdown().exists()).toBe(true);
        expect(findCopyLinkAction().exists()).toBe(true);
        expect(findDeleteNoteAction().exists()).toBe(true);
      });
    });
  });
});

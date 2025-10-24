import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { detectAndConfirmSensitiveTokens } from '~/lib/utils/secret_detection';
import { getDraft, clearDraft, updateDraft } from '~/lib/utils/autosave';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import ComplianceViolationCommentForm from 'ee/compliance_violations/components/compliance_violation_comment_form.vue';
import createNoteMutation from 'ee/compliance_violations/graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

Vue.use(VueApollo);

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('~/lib/utils/secret_detection');
jest.mock('~/lib/utils/autosave');
jest.mock('~/vue_shared/components/markdown/tracking');

describe('ComplianceViolationCommentForm', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    violationId: 'gid://gitlab/ComplianceViolation/123',
    uploadsPath: '/uploads',
    markdownPreviewPath: '/preview',
  };

  const mockNote = {
    id: 'gid://gitlab/Note/456',
    body: 'Test comment',
    bodyHtml: '<p>Test comment</p>',
    author: {
      name: 'Test User',
      username: 'testuser',
    },
  };

  const mockCreateNoteSuccess = {
    data: {
      createNote: {
        errors: [],
        note: mockNote,
      },
    },
  };

  const mockCreateNoteError = {
    data: {
      createNote: {
        errors: ['Something went wrong'],
        note: null,
      },
    },
  };

  const mockComplianceViolationData = {
    projectComplianceViolation: {
      id: 'gid://gitlab/ComplianceViolation/123',
      notes: {
        nodes: [],
      },
    },
  };

  const createComponent = ({
    props = {},
    createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess),
  } = {}) => {
    mockApollo = createMockApollo([[createNoteMutation, createNoteMutationHandler]]);

    // Mock the cache read for updateCache method
    mockApollo.defaultClient.cache.readQuery = jest
      .fn()
      .mockReturnValue(mockComplianceViolationData);
    mockApollo.defaultClient.cache.writeQuery = jest.fn();

    wrapper = shallowMountExtended(ComplianceViolationCommentForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
    });
  };

  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findCommentButton = () => wrapper.findByTestId('comment-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');

  beforeEach(() => {
    getDraft.mockReturnValue('');
    confirmAction.mockResolvedValue(true);
    detectAndConfirmSensitiveTokens.mockResolvedValue(true);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders MarkdownEditor', () => {
      expect(findMarkdownEditor().exists()).toBe(true);
    });

    it('renders comment button', () => {
      const commentButton = findCommentButton();

      expect(commentButton.exists()).toBe(true);
      expect(commentButton.text()).toBe('Comment');
    });

    it('renders cancel button', () => {
      const cancelButton = findCancelButton();

      expect(cancelButton.exists()).toBe(true);
      expect(cancelButton.text()).toBe('Cancel');
    });
  });

  describe('autosave functionality', () => {
    it('generates autosaveKey from violationId', () => {
      createComponent();

      expect(getDraft).toHaveBeenCalledWith(
        'compliance-violation-comment-gid://gitlab/ComplianceViolation/123',
      );
    });

    it('loads draft content on initialization', () => {
      const draftContent = 'Draft comment';
      getDraft.mockReturnValue(draftContent);

      createComponent();

      expect(wrapper.vm.commentText).toBe(draftContent);
    });

    it('uses empty initial value when no draft exists', () => {
      getDraft.mockReturnValue('');

      createComponent();

      expect(wrapper.vm.commentText).toBe('');
    });

    it('updates draft when comment text changes', async () => {
      createComponent();
      const newText = 'New comment text';

      await findMarkdownEditor().vm.$emit('input', newText);

      expect(updateDraft).toHaveBeenCalledWith(
        'compliance-violation-comment-gid://gitlab/ComplianceViolation/123',
        newText,
      );
    });

    it('does not update draft when submitting', async () => {
      createComponent({ props: { isSubmitting: true } });
      const newText = 'New comment text';

      await findMarkdownEditor().vm.$emit('input', newText);

      expect(updateDraft).not.toHaveBeenCalled();
      expect(wrapper.vm.commentText).toBe('');
    });

    it('does not update draft when creating comment', async () => {
      createComponent();
      wrapper.vm.isCreatingComment = true;
      const newText = 'New comment text';

      await findMarkdownEditor().vm.$emit('input', newText);

      expect(updateDraft).not.toHaveBeenCalled();
      expect(wrapper.vm.commentText).toBe('');
    });
  });

  describe('form submission', () => {
    it('disabled comment button when no text is provided', () => {
      createComponent();

      expect(findCommentButton().props('disabled')).toBe(true);
    });

    it('enables comment button when text is provided', async () => {
      createComponent();
      wrapper.vm.commentText = 'Test comment';
      await nextTick();

      expect(findCommentButton().props('disabled')).toBe(false);
    });

    it('submits form successfully', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(detectAndConfirmSensitiveTokens).toHaveBeenCalledWith({
        content: 'Test comment',
      });
      expect(createNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          noteableId: 'gid://gitlab/ComplianceViolation/123',
          body: 'Test comment',
        },
      });
      expect(clearDraft).toHaveBeenCalledWith(
        'compliance-violation-comment-gid://gitlab/ComplianceViolation/123',
      );
    });

    it('handles sensitive token detection cancellation', async () => {
      detectAndConfirmSensitiveTokens.mockResolvedValue(false);
      const createNoteMutationHandler = jest.fn();
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(createNoteMutationHandler).not.toHaveBeenCalled();
      expect(wrapper.emitted('commentCreated')).toBeUndefined();
    });

    it('handles mutation errors', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteError);
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('commentCreated')).toBeUndefined();
    });

    it('handles network errors', async () => {
      const createNoteMutationHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('commentCreated')).toBeUndefined();
    });

    it('shows loading state during submission', async () => {
      const createNoteMutationHandler = jest.fn().mockImplementation(() => {
        return new Promise(() => {
          // Never resolves to keep loading state
        });
      });

      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';
      detectAndConfirmSensitiveTokens.mockResolvedValue(true);

      findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.vm.isCreatingComment).toBe(true);
      expect(findCommentButton().props('loading')).toBe(true);
      expect(findCommentButton().props('disabled')).toBe(true);
    });

    it('does not submit when comment text is empty', async () => {
      const createNoteMutationHandler = jest.fn();
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = '';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(createNoteMutationHandler).not.toHaveBeenCalled();
    });

    it('does not submit when comment text is only whitespace', async () => {
      const createNoteMutationHandler = jest.fn();
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = '   \n\t  ';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(createNoteMutationHandler).not.toHaveBeenCalled();
    });
  });

  describe('cancel editing', () => {
    it('emits cancelEditing when cancel button is clicked', async () => {
      createComponent();

      await findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancelEditing')).toHaveLength(1);
    });

    it('shows confirmation dialog when there are unsaved changes', async () => {
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');

      expect(confirmAction).toHaveBeenCalledWith(
        'Are you sure you want to cancel creating this comment?',
        {
          primaryBtnText: 'Discard changes',
          cancelBtnText: 'Continue editing',
          primaryBtnVariant: 'danger',
        },
      );
    });

    it('does not show confirmation when no changes made', async () => {
      createComponent();

      await findCancelButton().vm.$emit('click');

      expect(confirmAction).not.toHaveBeenCalled();
      expect(clearDraft).toHaveBeenCalled();
      expect(wrapper.emitted('cancelEditing')).toHaveLength(1);
    });

    it('continues editing when confirmation is cancelled', async () => {
      confirmAction.mockResolvedValue(false);
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancelEditing')).toBeUndefined();
      expect(clearDraft).not.toHaveBeenCalled();
    });

    it('clears draft and resets form when confirmed', async () => {
      confirmAction.mockResolvedValue(true);
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');
      await waitForPromises();

      expect(clearDraft).toHaveBeenCalledWith(
        'compliance-violation-comment-gid://gitlab/ComplianceViolation/123',
      );
      expect(wrapper.vm.commentText).toBe('');
      expect(wrapper.emitted('cancelEditing')).toHaveLength(1);
    });
  });

  describe('cache updates', () => {
    it('updates Apollo cache when note is created', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });
      wrapper.vm.commentText = 'Test comment';

      await findCommentButton().vm.$emit('click');
      await waitForPromises();

      expect(mockApollo.defaultClient.cache.readQuery).toHaveBeenCalledWith({
        query: complianceViolationQuery,
        variables: { id: 'gid://gitlab/ComplianceViolation/123' },
      });

      expect(mockApollo.defaultClient.cache.writeQuery).toHaveBeenCalledWith({
        query: complianceViolationQuery,
        variables: { id: 'gid://gitlab/ComplianceViolation/123' },
        data: {
          projectComplianceViolation: {
            id: 'gid://gitlab/ComplianceViolation/123',
            notes: {
              nodes: [{}],
            },
          },
        },
      });
    });
  });
});

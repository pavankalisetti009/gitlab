import { initMarkdownEditor as initMarkdownEditorFOSS } from '~/pages/projects/merge_requests/init_markdown_editor';
import { parseBoolean } from '~/lib/utils/common_utils';
import { descriptionComposerAction } from 'ee/ai/editor_actions/description_composer';

export function initMarkdownEditor() {
  const {
    projectId,
    targetBranch,
    sourceBranch,
    canSummarize,
    summarizeDisabledReason,
    canUseComposer,
  } = document.querySelector('.js-markdown-editor').dataset;

  return initMarkdownEditorFOSS({
    projectId,
    targetBranch,
    sourceBranch,
    canSummarizeChanges: parseBoolean(canSummarize),
    summarizeDisabledReason,
    editorAiActions: [parseBoolean(canUseComposer ?? false) && descriptionComposerAction()].filter(
      Boolean,
    ),
  });
}

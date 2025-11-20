import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { formatDefaultModelText } from 'ee/ai/shared/model_selection/utils';

describe('formatDefaultModelText', () => {
  it('returns formatted default model name', () => {
    const defaultModel = { name: 'Claude Sonnet 4.5', ref: GITLAB_DEFAULT_MODEL };

    expect(formatDefaultModelText(defaultModel)).toBe('Claude Sonnet 4.5 - Default');
  });
});

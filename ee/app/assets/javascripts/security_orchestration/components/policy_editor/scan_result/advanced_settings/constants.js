import { s__ } from '~/locale';

export const CLOSED = 'closed';

export const OPEN = 'open';

export const UNBLOCK_RULES_KEY = 'unblock_rules_using_execution_policies';

export const UNBLOCK_RULES_TEXT = s__(
  'ScanResultPolicy|Make approval rules optional using execution policies',
);

export const ROLES = 'roles';
export const GROUPS = 'groups';
export const ACCOUNT_TOKENS = 'account_tokens';
export const SOURCE_BRANCH_PATTERNS = 'source_branch_patterns';

export const EXCEPTION_OPTIONS_MAP = {
  [ROLES]: s__('ScanResultPolicy|Roles'),
  [GROUPS]: s__('Roles|Groups'),
  [ACCOUNT_TOKENS]: s__('AccountTokens|Service Account/Tokens'),
  [SOURCE_BRANCH_PATTERNS]: s__('SourceBranchPattern|Source branch patterns'),
};

export const EXCEPTION_OPTIONS = Object.entries(EXCEPTION_OPTIONS_MAP).map(([key, value]) => ({
  key,
  value,
}));

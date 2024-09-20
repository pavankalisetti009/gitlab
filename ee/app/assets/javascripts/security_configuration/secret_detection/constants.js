import { s__ } from '~/locale';

export const ExclusionType = {
  PATH: 'PATH',
  RAW: 'RAW_VALUE',
  REGEX: 'REGEX_PATTERN',
  RULE: 'RULE',
};

export const StatusType = {
  ENABLE: 'enable',
  DISABLE: 'disable',
};

export const ExclusionScannerEnum = {
  SECRET_PUSH_PROTECTION: 'SECRET_PUSH_PROTECTION',
};

export const EXCLUSION_TYPES = [
  {
    text: s__('SecurityExclusions|Path'),
    value: ExclusionType.PATH,
    description: s__('SecurityExclusions|File or directory location'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more paths to exclude, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: spec/**/*.rb'),
  },
  {
    text: s__('SecurityExclusions|Raw value'),
    value: ExclusionType.RAW,
    description: s__('SecurityExclusions|Unprocessed data'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more raw values to ignore, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: glpat-1234567890'),
  },
  // {
  //   text: s__('SecurityExclusions|Regex'),
  //   value: ExclusionType.REGEX,
  //   description: s__('SecurityExclusions|Pattern matching rules'),
  //   contentDescription: s__(
  //     'SecurityExclusions|Enter one or more regex patterns to ignore, separated by line breaks.',
  //   ),
  //   contentPlaceholder: s__('SecurityExclusions|ex: ^.*secret.*$'),
  // },
  {
    text: s__('SecurityExclusions|Rule'),
    value: ExclusionType.RULE,
    description: s__('SecurityExclusions|Scanner rule identifier'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more rules to ignore, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: gitlab_personal_access_token'),
  },
];

export const STATUS_TYPES = [
  { text: s__('SecurityExclusions|Enable'), value: StatusType.ENABLE },
  { text: s__('SecurityExclusions|Disable'), value: StatusType.DISABLE },
];

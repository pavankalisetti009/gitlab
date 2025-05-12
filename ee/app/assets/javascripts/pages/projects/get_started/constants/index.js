import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const ICON_TYPE_EMPTY = 'dash-circle';
export const ICON_TYPE_PARTIAL = 'check-circle-dashed';
export const ICON_TYPE_COMPLETED = 'check';

export const INVITE_URL_TYPE = 'invite';

export const GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK =
  'https://university.gitlab.com/courses/10-best-practices-for-using-duo-chat';

export const LEARN_MORE_LINKS = [
  {
    text: __('Git'),
    url: helpPagePath('topics/git/get_started'),
  },
  {
    text: __('Managing code'),
    url: helpPagePath('user/get_started/get_started_managing_code'),
  },
  {
    text: __('GitLab Duo'),
    url: helpPagePath('user/get_started/getting_started_gitlab_duo'),
  },
  {
    text: __('Organize work with projects'),
    url: helpPagePath('user/get_started/get_started_projects'),
  },
  {
    text: __('GitLab CI/CD'),
    url: helpPagePath('ci/_index.md'),
  },
  {
    text: __('SSH Keys'),
    url: helpPagePath('user/ssh'),
  },
];

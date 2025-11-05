import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const PREMIUM_MESSAGES_DURING_TRIAL = {
  project: {
    title: s__('ProjectCard|Accelerate your workflow with GitLab Duo Core'),
    learnMoreLink: helpPagePath('user/gitlab_duo/_index'),
    content: s__(
      'ProjectCard|AI across the software development lifecycle. To keep this Premium feature, upgrade before your trial ends.',
    ),
  },
  repository: {
    title: s__('ProjectCard|Keep your repositories synchronized with pull mirroring'),
    learnMoreLink: helpPagePath('user/project/repository/mirror/pull'),
    content: s__(
      'ProjectCard|Automatically pull from upstream repositories. To keep this Premium feature, upgrade before your trial ends.',
    ),
  },
  mrs: {
    title: s__('ProjectCard|Control your merge request review process with approval rules'),
    learnMoreLink: helpPagePath('user/project/merge_requests/approvals/rules'),
    content: s__(
      'ProjectCard|Set approval requirements and specific reviewers. To keep this Premium feature, upgrade before your trial ends.',
    ),
  },
};

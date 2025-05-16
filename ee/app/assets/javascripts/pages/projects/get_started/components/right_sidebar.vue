<script>
import { GlIcon, GlButton, GlCard, GlLink } from '@gitlab/ui';
import GitlabUniversityDuoChatImgURL from 'ee_images/learn_gitlab/gitlab_university_duo_chat.png';
import { GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK, LEARN_MORE_LINKS } from '../constants';

export default {
  name: 'RightSidebar',
  components: {
    GlIcon,
    GlButton,
    GlCard,
    GlLink,
  },
  GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK,
  LEARN_MORE_LINKS,
  GitlabUniversityDuoChatImgURL,
};
</script>

<template>
  <div>
    <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|GitLab University') }}</h2>
    <gl-card class="gl-overflow-hidden gl-rounded-lg" header-class="gl-p-0" body-class="gl-p-3">
      <template #header>
        <img :src="$options.GitlabUniversityDuoChatImgURL" class="gl-w-full" aria-hidden="true" />
      </template>
      <template #default>
        <h3 class="gl-m-0 gl-text-base">
          {{ s__('LearnGitLab|10 best practices for using GitLab Duo') }}
        </h3>
        <p class="gl-my-3">
          {{
            s__(
              'LearnGitLab|In this tutorial, we explore 10 tips and best practices to integrate GitLab Duo Chat into your AI-native DevSecOps workflows and refine your prompts for the best results.',
            )
          }}
        </p>
        <gl-button :href="$options.GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK" category="primary">
          {{ s__('LearnGitLab|Enroll') }}
          <gl-icon name="external-link" />
        </gl-button>
      </template>
    </gl-card>
    <h2 class="gl-mb-3 gl-mt-7 gl-text-size-h2">{{ s__('LearnGitLab|Learn more') }}</h2>
    <ul class="gl-list-none gl-p-0">
      <li v-for="link in $options.LEARN_MORE_LINKS" :key="link.url" class="gl-mb-3">
        <gl-link :href="link.url">{{ link.text }}</gl-link>
      </li>
    </ul>
  </div>
</template>

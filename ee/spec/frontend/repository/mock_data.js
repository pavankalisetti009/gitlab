export const refMock = 'default-ref';

export const codeOwnersPath = 'path/to/codeowners/file';

export const codeOwnersMock = [
  { id: '1', name: 'Idella Welch', webPath: '/raisa' },
  { id: '2', name: 'Winston Von', webPath: '/noella' },
  { id: '3', name: 'Don Runte', webPath: '/edyth' },
  { id: '4', name: 'Sherri McClure', webPath: '/julietta_rogahn' },
  { id: '5', name: 'Amber Koch', webPath: '/youlanda' },
  { id: '6', name: 'Van Schmitt', webPath: '/hortensia' },
  { id: '7', name: 'Larita Hamill', webPath: '/alesia' },
];

export const codeOwnersPropsMock = {
  projectPath: 'some/project',
  filePath: 'some/file',
  branch: 'main',
  branchRulesPath: '/some/Project/-/settings/repository#js-branch-rules',
  canViewBranchRules: true,
};

export const headerAppInjected = {
  canCollaborate: true,
  canEditTree: true,
  canPushCode: true,
  originalBranch: 'main',
  selectedBranch: 'feature/new-ui',
  newBranchPath: '/project/new-branch',
  newTagPath: '/project/new-tag',
  newBlobPath: '/project/new-file',
  forkNewBlobPath: '/project/fork/new-file',
  forkNewDirectoryPath: '/project/fork/new-directory',
  forkUploadBlobPath: '/project/fork/upload',
  uploadPath: '/project/upload',
  newDirPath: '/project/new-directory',
  projectRootPath: '/project/root/path',
  comparePath: undefined,
  isReadmeView: false,
  isFork: false,
  needsToFork: true,
  gitpodEnabled: false,
  isBlob: true,
  showEditButton: true,
  showWebIdeButton: true,
  showGitpodButton: false,
  showPipelineEditorUrl: true,
  webIdeUrl: 'https://gitlab.com/project/-/ide/',
  editUrl: 'https://gitlab.com/project/-/edit/main/',
  pipelineEditorUrl: 'https://gitlab.com/project/-/ci/editor',
  gitpodUrl: 'https://gitpod.io/#https://gitlab.com/project',
  userPreferencesGitpodPath: '/profile/preferences#gitpod',
  userProfileEnableGitpodPath: '/profile/preferences?enable_gitpod=true',
  httpUrl: 'https://gitlab.com/example-group/example-project.git',
  xcodeUrl: 'xcode://clone?repo=https://gitlab.com/example-group/example-project.git',
  sshUrl: 'git@gitlab.com:example-group/example-project.git',
  kerberosUrl: 'https://kerberos@gitlab.com/example-group/example-project.git',
  downloadLinks: [
    'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.zip',
    'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.tar.gz',
    'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.tar.bz2',
    'https://gitlab.com/example-group/example-project/-/releases',
  ],
  downloadArtifacts: [
    'https://gitlab.com/example-group/example-project/-/jobs/artifacts/main/download?job=build',
  ],
};

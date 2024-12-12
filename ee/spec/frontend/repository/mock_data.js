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

export const userPermissionsMock = {
  pushCode: true,
  forkProject: true,
  downloadCode: true,
  createMergeRequestIn: true,
  adminPathLocks: true,
  __typename: 'ProjectPermissions',
};

export const projectMock = {
  __typename: 'Project',
  id: 'gid://gitlab/Project/7',
  userPermissions: userPermissionsMock,
  pathLocks: {
    __typename: 'PathLockConnection',
    nodes: [
      {
        __typename: 'PathLock',
        id: 'gid://gitlab/PathLock/2',
        path: 'locked_file.js',
        user: {
          id: 'gid://gitlab/User/1',
          username: 'root',
          name: 'Administrator',
          __typename: 'UserCore',
        },
      },
    ],
  },
  repository: {
    empty: false,
  },
};

export const exactDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/1',
  path: 'test/component',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
  },
};

export const upstreamDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/3',
  path: 'test',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
  },
};

export const downstreamDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/2',
  path: 'test/component/icon',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
  },
};

export const userMock = {
  data: {
    currentUser: {
      __typename: 'CurrentUser',
      id: 'gid://gitlab/User/1',
      username: 'root',
      name: 'Administrator',
      avatarUrl: 'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80',
      webUrl: '/root',
      webPath: '/root',
    },
  },
};

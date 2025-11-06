export const MOCK_MODEL_TYPES = [
  {
    title: 'Upload',
    titlePlural: 'Uploads',
    name: 'upload',
    namePlural: 'uploads',
    modelClass: 'Upload',
    restEndpoint: '/api/v4/admin/data_management/upload',
    checksumEnabled: true,
  },
  {
    title: 'Terraform State Version',
    titlePlural: 'Terraform State Versions',
    name: 'terraform_state_version',
    namePlural: 'terraform_state_versions',
    modelClass: 'Terraform::StateVersion',
    restEndpoint: '/api/v4/admin/data_management/terraform_state_version',
    checksumEnabled: true,
  },
  {
    title: 'Snippet Repository',
    titlePlural: 'Snippet Repositories',
    name: 'snippet_repository',
    namePlural: 'snippet_repositories',
    modelClass: 'SnippetRepository',
    restEndpoint: '/api/v4/admin/data_management/snippet_repository',
    checksumEnabled: true,
  },
];

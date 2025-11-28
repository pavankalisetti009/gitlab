export const mockCacheEntries = [
  {
    id: 'NSAvdGVzdC9iYXI=',
    group_id: 209,
    upstream_id: 5,
    upstream_checked_at: '2025-05-19T14:22:23.048Z',
    file_md5: null,
    file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83',
    size: 15,
    relative_path: '/test/bar',
    upstream_etag: null,
    content_type: 'application/octet-stream',
    created_at: '2025-05-19T14:22:23.050Z',
    updated_at: '2025-05-19T14:22:23.050Z',
  },
];

export const mockUpstreams = [
  {
    id: 1,
    name: 'Maven Central',
    url: 'https://repo1.maven.org/maven2/',
    cache_validity_hours: 24,
    metadata_cache_validity_hours: 12,
  },
  {
    id: 2,
    name: 'JCenter',
    url: 'https://jcenter.bintray.com/',
    cache_validity_hours: 48,
    metadata_cache_validity_hours: 24,
  },
];

export const mockUpstream = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
};

export const mockUpstreamPagination = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
  cacheEntriesCount: 22,
};

export const mavenVirtualRegistry = {
  __typename: 'MavenVirtualRegistry',
  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/2',
  name: 'Maven Registry 1',
  description: '',
  updatedAt: '2023-05-17T08:00:00Z',
  upstreams: [
    {
      __typename: 'MavenUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/2',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
      name: 'Maven upstream',
      description: 'Maven Central',
      url: 'https://repo.maven.apache.org/maven2',
      registryUpstreams: [
        {
          __typename: 'MavenRegistryUpstream',

          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/2',
          position: 1,
        },
      ],
    },
    {
      __typename: 'MavenUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/5',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
      name: 'Maven upstream 4',
      description: null,
      url: 'https://repo.maven.apache.org/maven2',
      registryUpstreams: [
        {
          __typename: 'MavenRegistryUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/3',
          position: 2,
        },
      ],
    },
    {
      __typename: 'MavenUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/6',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
      name: 'Maven upstream 4',
      description: null,
      url: 'https://repo.maven.apache.org/maven2',
      registryUpstreams: [
        {
          __typename: 'MavenRegistryUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/4',
          position: 3,
        },
      ],
    },
    {
      __typename: 'MavenUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/7',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
      name: 'Maven upstream 4',
      description: null,
      url: 'https://repo.maven.apache.org/maven2',
      registryUpstreams: [
        {
          __typename: 'MavenRegistryUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/7',
          position: 4,
        },
      ],
    },
  ],
};

export const mavenUpstreamRegistry = {
  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/11',
  registryUpstreams: [
    {
      __typename: 'MavenRegistryUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/11',
      position: 2,
      registry: {
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/6',
        name: 'testing',
        __typename: 'MavenVirtualRegistry',
      },
    },
  ],
  __typename: 'MavenUpstream',
};

export const groupVirtualRegistries = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    virtualRegistriesPackagesMavenRegistries: {
      __typename: 'MavenVirtualRegistryConnection',
      nodes: [
        {
          __typename: 'MavenVirtualRegistry',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/2',
          name: 'Maven Registry 1',
          updatedAt: '2023-05-17T08:00:00Z',
        },
      ],
      pageInfo: {
        hasPreviousPage: false,
        hasNextPage: false,
        startCursor: 'start',
        endCursor: 'end',
        __typename: 'PageInfo',
      },
    },
  },
};

export const upstreamsResponse = {
  data: [
    {
      id: 3,
      name: 'test',
      description: 'test description',
      group_id: 122,
      url: 'https://gitlab.com',
      username: '',
      cache_validity_hours: 24,
      metadata_cache_validity_hours: 24,
      created_at: '2025-07-15T04:10:03.060Z',
      updated_at: '2025-07-15T04:11:00.426Z',
    },
  ],
  headers: {
    'x-total': '1',
  },
};

export const multipleUpstreamsResponse = {
  data: [
    {
      ...upstreamsResponse.data[0],
    },
    {
      id: 2,
      name: 'Maven upstream',
      description: 'Maven Central',
      group_id: 122,
      username: null,
      url: 'https://repo.maven.apache.org/maven2',
      cache_validity_hours: 24,
      metadata_cache_validity_hours: 48,
      created_at: '2025-07-15T04:10:03.060Z',
      updated_at: '2025-07-15T04:11:00.426Z',
    },
  ],
  headers: {
    'x-total': '2',
  },
};

export const mockVirtualRegistriesCleanupPolicy = (options = {}) => {
  const { enabled = true, nextRunAt = '2025-01-15T10:00:00Z' } = options;

  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        __typename: 'Group',
        virtualRegistriesCleanupPolicy: {
          __typename: 'VirtualRegistriesCleanupPolicy',
          enabled,
          nextRunAt: enabled ? nextRunAt : null,
        },
      },
    },
  };
};

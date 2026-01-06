export const mockUpstream = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
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

export const groupMavenUpstreamsCountResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/33',
      __typename: 'Group',
      virtualRegistriesPackagesMavenUpstreams: {
        __typename: 'MavenUpstreamConnection',
        count: 5,
      },
    },
  },
};

export const groupMavenUpstreams = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    virtualRegistriesPackagesMavenUpstreams: {
      __typename: 'MavenUpstreamConnection',
      nodes: [
        {
          __typename: 'MavenUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
          name: 'Maven Central',
          url: 'https://repo1.maven.org/maven2/',
          cacheValidityHours: 24,
          metadataCacheValidityHours: 12,
          registriesCount: 2,
        },
        {
          __typename: 'MavenUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/2',
          name: 'JCenter',
          url: 'https://jcenter.bintray.com/',
          cacheValidityHours: 48,
          metadataCacheValidityHours: 24,
          registriesCount: 1,
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

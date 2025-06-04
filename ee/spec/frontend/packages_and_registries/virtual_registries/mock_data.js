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

export const mockUpstream = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
  cacheEntriesCount: 1,
};

export const mockUpstreamPagination = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
  cacheEntriesCount: 22,
};

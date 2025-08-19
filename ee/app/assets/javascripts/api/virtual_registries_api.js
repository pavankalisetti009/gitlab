import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

const MAVEN_REGISTRY_CACHE_PATH =
  '/api/:version/virtual_registries/packages/maven/registries/:id/cache';
const MAVEN_UPSTREAM_PATH = '/api/:version/virtual_registries/packages/maven/upstreams/:id';
const MAVEN_UPSTREAM_CACHE_PATH = `${MAVEN_UPSTREAM_PATH}/cache`;
const MAVEN_UPSTREAM_CACHE_ENTRIES_PATH =
  '/api/:version/virtual_registries/packages/maven/upstreams/:id/cache_entries';
const MAVEN_UPSTREAM_CACHE_ENTRY_PATH =
  '/api/:version/virtual_registries/packages/maven/cache_entries/:id';
const MAVEN_REGISTRY_UPSTREAM_PATH =
  '/api/:version/virtual_registries/packages/maven/registry_upstreams/:id';

const buildMavenUpstreamApiUrl = (id) => buildApiUrl(MAVEN_UPSTREAM_PATH).replace(':id', id);

export function updateMavenUpstream({ id, data }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.patch(url, {
    ...data,
  });
}

export function updateMavenRegistryUpstreamPosition({ id, position }) {
  const url = buildApiUrl(MAVEN_REGISTRY_UPSTREAM_PATH).replace(':id', id);

  return axios.patch(url, {
    position,
  });
}

export function deleteMavenUpstream({ id }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.delete(url);
}

export function getMavenUpstreamCacheEntries({ id, params = {} }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_ENTRIES_PATH).replace(':id', id);

  return axios.get(url, { params });
}

export function deleteMavenRegistryCache({ id }) {
  const url = buildApiUrl(MAVEN_REGISTRY_CACHE_PATH).replace(':id', id);

  return axios.delete(url);
}

export function deleteMavenUpstreamCache({ id }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_PATH).replace(':id', id);

  return axios.delete(url);
}

export function deleteMavenUpstreamCacheEntry({ id }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_ENTRY_PATH).replace(':id', id);

  return axios.delete(url);
}

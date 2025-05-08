import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

const MAVEN_REGISTRIES_PATH =
  '/api/:version/groups/:id/-/virtual_registries/packages/maven/registries';

export function getMavenVirtualRegistriesList({ id }) {
  const url = buildApiUrl(MAVEN_REGISTRIES_PATH).replace(':id', id);

  return axios.get(url);
}

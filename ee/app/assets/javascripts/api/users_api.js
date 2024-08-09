import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

export const PASSWORD_COMPLEXITY_PATH = '/users/password/complexity';

export function validatePasswordComplexity(password) {
  const url = buildApiUrl(PASSWORD_COMPLEXITY_PATH);

  const params = { password };

  return axios.post(url, params);
}

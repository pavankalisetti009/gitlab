import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

const DATA_MANAGEMENT_PATH = '/api/:version/admin/data_management/:model';

export const getModels = (model) => {
  const url = buildApiUrl(DATA_MANAGEMENT_PATH).replace(':model', model);

  return axios.get(url);
};

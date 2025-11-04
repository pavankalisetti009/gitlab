import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

const DATA_MANAGEMENT_PATH = '/api/:version/admin/data_management/:model';
const DATA_MANAGEMENT_ACTION_PATH =
  '/api/:version/admin/data_management/:model/:recordIdentifier/:action';

export const getModels = (model, params = {}) => {
  const url = buildApiUrl(DATA_MANAGEMENT_PATH).replace(':model', model);

  return axios.get(url, { params });
};

export const putModelAction = (model, recordIdentifier, action) => {
  const url = buildApiUrl(DATA_MANAGEMENT_ACTION_PATH)
    .replace(':model', model)
    .replace(':recordIdentifier', recordIdentifier)
    .replace(':action', action);

  return axios.put(url);
};

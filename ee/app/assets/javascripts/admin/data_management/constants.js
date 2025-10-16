import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const GEO_TROUBLESHOOTING_LINK = helpPagePath(
  'administration/geo/replication/troubleshooting/_index.md',
);

export const TOKEN_TYPES = {
  MODEL: 'model_name',
};

const SORT_OPTIONS = {
  ID: {
    text: s__('Geo|Model ID'),
    value: 'id',
  },
};

export const DEFAULT_SORT = {
  value: SORT_OPTIONS.ID.value,
  direction: SORT_DIRECTION.ASC,
};

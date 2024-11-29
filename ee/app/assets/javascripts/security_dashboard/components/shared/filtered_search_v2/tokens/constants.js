import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { ALL_ID } from '../../filters/constants';
import StatusToken from './status_token.vue';
import ActivityToken from './activity_token.vue';
import SeverityToken from './severity_token.vue';
import ToolToken from './tool_token.vue';
import ImageToken from './image_token.vue';
import ClusterToken from './cluster_token.vue';
import ProjectToken from './project_token.vue';

export const STATUS_TOKEN_DEFINITION = {
  type: 'state',
  title: StatusToken.i18n.statusLabel,
  multiSelect: true,
  unique: true,
  token: StatusToken,
  operators: OPERATORS_OR,
};

export const SEVERITY_TOKEN_DEFINITION = {
  type: 'severity',
  title: SeverityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: SeverityToken,
  operators: OPERATORS_OR,
  prepareFilters: (newValues, oldValues) => {
    // When the user clicks on the selected value (placeholder), the filtered search
    // empties the selection handler and sends a null value
    // We don't want to cause a new API call when this happens. Instead
    // we want to wait until user either destroys the token or selects a new token.
    if (!newValues) {
      return oldValues;
    }

    return newValues.filter((i) => i !== ALL_ID);
  },
};

export const ACTIVITY_TOKEN_DEFINITION = {
  type: 'activity',
  title: ActivityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ActivityToken,
  operators: OPERATORS_OR,
};

export const TOOL_VENDOR_TOKEN_DEFINITION = {
  type: 'scanner',
  title: ToolToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ToolToken,
  operators: OPERATORS_OR,
};

export const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ProjectToken,
  operators: OPERATORS_OR,
};

export const IMAGE_TOKEN_DEFINITION = {
  type: 'image',
  title: ImageToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ImageToken,
  operators: OPERATORS_OR,
};

export const CLUSTER_TOKEN_DEFINITION = {
  type: 'cluster',
  title: ClusterToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ClusterToken,
  operators: OPERATORS_OR,
};

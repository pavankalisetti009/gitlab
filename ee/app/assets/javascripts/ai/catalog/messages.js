import { s__ } from '~/locale';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from './constants';

export const DISABLE_SUCCESS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|Agent disabled in this %{namespaceType}.'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|Flow disabled in this %{namespaceType}.'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|Flow disabled in this %{namespaceType}.'),
};
export const DISABLE_ERROR = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|Failed to disable agent'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|Failed to disable flow'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|Failed to disable flow'),
};

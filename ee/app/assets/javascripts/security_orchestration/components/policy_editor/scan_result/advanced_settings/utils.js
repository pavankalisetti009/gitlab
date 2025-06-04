import { uniqueId } from 'lodash';

export const createSourceBranchPatternObject = ({ id = '', source = {}, target = {} } = {}) => ({
  id: id || uniqueId('pattern_'),
  source,
  target,
});

import isEmpty from 'lodash/isEmpty';
import uniqueId from 'lodash/uniqueId';

export const isEmptyPanelData = (visualizationType, data) => {
  if (visualizationType === 'SingleStat') {
    // SingleStat visualizations currently do not show an empty state, and instead show a default "0" value
    // This will be revisited: https://gitlab.com/gitlab-org/gitlab/-/issues/398792
    return false;
  }
  return isEmpty(data);
};

export const getUniquePanelId = () => uniqueId('panel-');

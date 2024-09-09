export const selectedLabelNames = ({ selectedLabels = [] }) => {
  return selectedLabels.map(({ title }) => title);
};

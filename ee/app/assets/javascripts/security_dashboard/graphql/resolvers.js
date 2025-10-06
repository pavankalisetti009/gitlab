const aiFixInProgress = (vulnerability) => {
  if (!gon.features?.agenticSastVrUi) {
    return false;
  }

  // Mock logic: vulnerabilities with IDs ending in certain digits have workflows in progress
  const vulnerabilityId = vulnerability.id;
  if (!vulnerabilityId) return false;

  const numericId = vulnerabilityId.split('/').pop();
  if (!numericId) return false;

  const lastDigit = parseInt(numericId.slice(-1), 10);
  return [1, 3, 7, 9].includes(lastDigit);
};

export const vulnerabilityResolvers = {
  Vulnerability: {
    aiFixInProgress,
  },
};

export default {
  ...vulnerabilityResolvers,
};

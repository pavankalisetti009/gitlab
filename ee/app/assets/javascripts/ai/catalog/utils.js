export const mapSteps = (steps) =>
  steps.nodes.map((s) => ({
    id: s.agent.id,
    name: s.agent.name,
    versions: s.agent.versions,
    versionName: s.pinnedVersionPrefix,
  }));

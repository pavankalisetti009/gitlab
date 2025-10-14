import { mapSteps } from 'ee/ai/catalog/utils';
import { mockBaseAgent } from './mock_data';

describe('mapSteps', () => {
  it('maps steps nodes to simplified agent objects', () => {
    const steps = {
      nodes: [
        {
          agent: { ...mockBaseAgent, id: 'agent-1', name: 'Agent 1' },
          pinnedVersionPrefix: 'v1.0',
        },
        {
          agent: { ...mockBaseAgent, id: 'agent-2', name: 'Agent 2' },
          pinnedVersionPrefix: 'v2.0',
        },
      ],
    };

    const result = mapSteps(steps);

    expect(result).toEqual([
      {
        id: 'agent-1',
        name: 'Agent 1',
        versions: mockBaseAgent.versions,
        versionName: 'v1.0',
      },
      {
        id: 'agent-2',
        name: 'Agent 2',
        versions: mockBaseAgent.versions,
        versionName: 'v2.0',
      },
    ]);
  });
});

import { mapSteps, createAvailableFlowItemTypes } from 'ee/ai/catalog/utils';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';
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

describe('createAvailableFlowItemTypes', () => {
  it('returns both flow types when both flags are enabled', () => {
    const types = createAvailableFlowItemTypes({
      isFlowsEnabled: true,
      isThirdPartyFlowsEnabled: true,
    });

    expect(types).toStrictEqual([AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW]);
  });

  it('returns only flow type when only flows are enabled', () => {
    const types = createAvailableFlowItemTypes({
      isFlowsEnabled: true,
      isThirdPartyFlowsEnabled: false,
    });

    expect(types).toStrictEqual([AI_CATALOG_TYPE_FLOW]);
  });

  it('returns only third party flow type when only third party flows are enabled', () => {
    const types = createAvailableFlowItemTypes({
      isFlowsEnabled: false,
      isThirdPartyFlowsEnabled: true,
    });

    expect(types).toStrictEqual([AI_CATALOG_TYPE_THIRD_PARTY_FLOW]);
  });

  it('returns empty array when both flags are disabled', () => {
    const types = createAvailableFlowItemTypes({
      isFlowsEnabled: false,
      isThirdPartyFlowsEnabled: false,
    });

    expect(types).toStrictEqual([]);
  });
});

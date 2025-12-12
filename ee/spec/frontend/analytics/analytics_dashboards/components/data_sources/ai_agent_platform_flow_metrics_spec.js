import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_agent_platform_flow_metrics';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { DATE_RANGE_OPTION_LAST_7_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

const mockFlowMetrics = [
  {
    flowType: 'AGENT_FLOW',
    medianExecutionTime: 1250,
    sessionsCount: 145,
    usersCount: 32,
    completionRate: 92.5,
  },
  {
    flowType: 'TOOL_FLOW',
    medianExecutionTime: 850,
    sessionsCount: 203,
    usersCount: 48,
    completionRate: 88.3,
  },
  {
    flowType: 'CUSTOM_FLOW',
    medianExecutionTime: 2100,
    sessionsCount: 87,
    usersCount: 19,
    completionRate: 95.1,
  },
  {
    flowType: 'BONUS_FLOW',
    medianExecutionTime: 2100,
    sessionsCount: 87,
    usersCount: 19,
    completionRate: 95.1,
  },
];

const mockTooManyFlowMetrics = [...mockFlowMetrics, ...mockFlowMetrics, ...mockFlowMetrics];

describe('AI Agent platform flow metrics data source', () => {
  const namespace = 'namespace';

  const mockResolvedQuery = (flowMetrics = mockFlowMetrics) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({
      data: {
        group: { id: 'gid://gitlab/Group/1', aiMetrics: { agentPlatform: { flowMetrics } } },
      },
    });

  it('returns the flow metrics as nodes on success', async () => {
    mockResolvedQuery();

    const result = await fetch({ namespace });
    expect(result).toMatchSnapshot();
  });

  it('uses 30 days as the default date range', async () => {
    mockResolvedQuery();
    await fetch({ namespace });

    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: new Date('2020-06-06'),
          endDate: new Date('2020-07-06'),
        }),
      }),
    );
  });

  it('uses a custom date range when defined', async () => {
    mockResolvedQuery();
    await fetch({
      namespace,
      queryOverrides: { dateRange: DATE_RANGE_OPTION_LAST_7_DAYS },
    });

    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: new Date('2020-06-29'),
          endDate: new Date('2020-07-06'),
        }),
      }),
    );
  });

  it('limits to 10 returned nodes', async () => {
    mockResolvedQuery(mockTooManyFlowMetrics);
    const result = await fetch({ namespace });
    expect(result.nodes).toHaveLength(10);
  });

  it.each([
    ['sessionsCount', true],
    ['sessionsCount', false],
    ['medianExecutionTime', true],
    ['medianExecutionTime', false],
    ['usersCount', true],
    ['usersCount', false],
  ])('applies correct sorting for (sortBy: %s, sortDesc: %s)', async (sortBy, sortDesc) => {
    mockResolvedQuery();
    const result = await fetch({
      namespace,
      queryOverrides: { sortBy, sortDesc },
    });

    expect(result.nodes).toMatchSnapshot();
  });
});

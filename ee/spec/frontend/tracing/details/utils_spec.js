import { createIssueUrlWithTraceDetails } from 'ee/tracing/details/utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockTrace } from '../mock_data';

describe('createIssueUrlWithTraceDetails', () => {
  const mockTrace = createMockTrace();

  const mockCreateIssueUrl = 'https://example.com/create-issue';

  beforeEach(() => {
    setWindowLocation('https://test.com/tracing/abcd1234');
  });

  it('should create a URL with correct log details', () => {
    const result = createIssueUrlWithTraceDetails({
      trace: mockTrace,
      createIssueUrl: mockCreateIssueUrl,
      totalErrors: 2,
    });

    const createIssueURL = new URL(result);
    const queryParamTraceDetails = JSON.parse(
      createIssueURL.searchParams.get('observability_trace_details'),
    );

    expect(createIssueURL.origin + createIssueURL.pathname).toBe(mockCreateIssueUrl);
    expect(queryParamTraceDetails).toEqual({
      fullUrl: 'https://test.com/tracing/abcd1234',
      traceId: '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8',
      name: `Service : Operation`,
      start: 'Mon, 14 Aug 2023 14:05:37 GMT',
      duration: '1s',
      totalSpans: 10,
      totalErrors: 2,
    });
  });
});

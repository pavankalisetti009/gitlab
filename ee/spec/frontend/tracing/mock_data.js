import { times } from 'lodash';

export const createMockTrace = (spansNumber) => {
  const trace = { duration_nane: 100000, spans: [] };
  trace.spans = times(spansNumber).map((i) => ({
    timestamp: new Date().toISOString(),
    span_id: `SPAN-${i}`,
    trace_id: 'fake-trace',
    service_name: `service-${i}`,
    operation: 'op',
    duration_nano: 100000,
    parent_span_id: i === 0 ? '' : 'SPAN-0',
  }));
  return trace;
};

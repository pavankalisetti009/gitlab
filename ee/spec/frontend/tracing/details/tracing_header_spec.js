import { GlBadge, GlButton } from '@gitlab/ui';
import TracingHeader from 'ee/tracing/details/tracing_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { createMockTrace } from '../mock_data';

describe('TracingHeader', () => {
  let wrapper;

  const defaultTrace = createMockTrace();

  const createComponent = (trace = defaultTrace, incomplete = false) => {
    wrapper = shallowMountExtended(TracingHeader, {
      propsData: {
        trace,
        incomplete,
        logsLink: 'testLogsLink',
        createIssueUrl: 'testCreateIssueUrl',
        totalErrors: 2,
      },
    });
  };
  beforeEach(() => {
    createComponent();
  });

  const findHeading = () => wrapper.findComponent(PageHeading);

  it('renders the correct title', () => {
    expect(findHeading().text()).toContain('Service : Operation');
  });

  it('does not show the in progress label if incomplete=false', () => {
    expect(findHeading().findComponent(GlBadge).exists()).toBe(false);

    expect(findHeading().text()).not.toContain('In progress');
  });

  it('shows the in progress label when incomplete=true', () => {
    createComponent(
      {
        ...defaultTrace,
      },
      true,
    );

    expect(findHeading().findComponent(GlBadge).exists()).toBe(true);
    expect(findHeading().text()).toContain('In progress');
  });

  it('renders the correct logs link', () => {
    const button = findHeading().findAllComponents(GlButton).at(1);
    expect(button.text()).toBe('View Logs');
    expect(button.attributes('href')).toBe('testLogsLink');
  });

  it('renders the create issue link', () => {
    const button = findHeading().findAllComponents(GlButton).at(0);
    expect(button.text()).toBe('Create issue');
    const traceDetails = {
      fullUrl: 'http://test.host/',
      name: `Service : Operation`,
      traceId: '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8',
      start: 'Mon, 14 Aug 2023 14:05:37 GMT',
      duration: '1s',
      totalSpans: 10,
      totalErrors: 2,
    };
    expect(button.attributes('href')).toBe(
      `testCreateIssueUrl?observability_trace_details=${encodeURIComponent(
        JSON.stringify(traceDetails),
      )}`,
    );
  });

  it('renders the correct trace date', () => {
    expect(wrapper.findByTestId('trace-date-card').text()).toMatchInterpolatedText(
      'Trace start Aug 14, 2023 14:05:37.219 UTC',
    );
  });

  it('renders the correct trace duration', () => {
    expect(wrapper.findByTestId('trace-duration-card').text()).toMatchInterpolatedText(
      'Duration 1s',
    );
  });

  it('renders the correct total spans', () => {
    expect(wrapper.findByTestId('trace-spans-card').text()).toMatchInterpolatedText(
      'Total spans 10',
    );
  });
});

import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import ScanTriggersDetail from 'ee/security_configuration/components/scan_profiles/scan_triggers_detail.vue';

jest.mock('~/helpers/help_page_helper', () => ({
  helpPagePath: jest.fn(),
}));

const mockDocsPath = '/help/user/application_security/secret_detection/secret_push_protection';

describe('ScanTriggersDetail', () => {
  let wrapper;

  const findCrud = () => wrapper.findComponent(CrudComponent);
  const findDocsButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    helpPagePath.mockReturnValue(mockDocsPath);
    wrapper = shallowMountExtended(ScanTriggersDetail);
  });

  it('renders CrudComponent with correct props', () => {
    expect(findCrud().props()).toMatchObject({
      isCollapsible: true,
      collapsed: true,
      title: 'Git Push Events',
      description: 'Scan all Git push events and block pushes with detected secrets.',
      anchorId: 'git-push-events',
      icon: 'push-rules',
    });
  });

  it('renders description text', () => {
    expect(wrapper.text()).toContain(
      'Block secrets such as keys and API tokens from being pushed to your repositories.',
    );
  });

  it('renders documentation link', () => {
    const button = findDocsButton();

    expect(button.props()).toMatchObject({
      variant: 'link',
      href: mockDocsPath,
    });
    expect(button.attributes('target')).toBe('_blank');
    expect(button.text()).toBe('View documentation');
    expect(button.attributes('href')).toBe(mockDocsPath);
  });
});

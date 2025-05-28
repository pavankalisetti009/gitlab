import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button.vue';

jest.mock('~/alert');

describe('PdfExportButton', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(PdfExportButton);
  };

  const findButton = () => wrapper.findComponent(GlButton);

  it('renders the button', () => {
    createWrapper();
    expect(findButton().props()).toMatchObject({
      category: 'secondary',
      icon: 'export',
    });
    expect(findButton().attributes('title')).toBe('Export as PDF');
    expect(findButton().text()).toBe('Export');
  });

  it('shows the alert on click', () => {
    createWrapper();

    expect(createAlert).not.toHaveBeenCalled();

    findButton().vm.$emit('click');

    expect(createAlert).toHaveBeenCalledWith({
      message:
        'Report export in progress. After the report is generated, an email will be sent with the download link.',
      variant: 'info',
      dismissible: true,
    });
  });
});

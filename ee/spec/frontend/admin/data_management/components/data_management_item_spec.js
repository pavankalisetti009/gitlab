import { shallowMount } from '@vue/test-utils';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { ACTION_TYPES } from 'ee/admin/data_management/constants';
import { createAlert } from '~/alert';
import { putModelAction } from 'ee/api/data_management_api';
import showToast from '~/vue_shared/plugins/global_toast';
import waitForPromises from 'helpers/wait_for_promises';
import { VERIFICATION_STATUS_LABELS, VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');
jest.mock('~/vue_shared/plugins/global_toast');

describe('DataManagementItem', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });
  const modelDisplayName = `${model.modelClass}/${model.recordIdentifier}`;

  const checksumAction = {
    id: 'geo-checksum-item',
    value: ACTION_TYPES.CHECKSUM,
    text: 'Checksum',
    loading: false,
    successMessage: `Successfully recalculated checksum for ${modelDisplayName}.`,
    errorMessage: `There was an error recalculating checksum for ${modelDisplayName}.`,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DataManagementItem, {
      propsData: {
        modelName: model.modelClass,
        initialItem: model,
        ...props,
      },
    });
  };

  const findGeoListItem = () => wrapper.findComponent(GeoListItem);
  const fireActionClicked = (action) => findGeoListItem().vm.$emit('actionClicked', action);

  it('renders GeoListItem with correct props', () => {
    createComponent();

    expect(findGeoListItem().props()).toMatchObject({
      name: modelDisplayName,
      timeAgoArray: [
        {
          label: 'Created',
          dateString: model.createdAt,
          defaultText: 'Unknown',
        },
        {
          label: 'Last checksum',
          dateString: model.checksumInformation.lastChecksum,
          defaultText: 'Unknown',
        },
      ],
      actionsArray: [checksumAction],
    });
  });

  describe('when GeoListItem emits checksumAction clicked event', () => {
    beforeEach(() => {
      createComponent();
    });

    it('starts loading state', async () => {
      await fireActionClicked(checksumAction);

      expect(findGeoListItem().props('actionsArray')[0].loading).toBe(true);
    });

    it('calls putModelAction', () => {
      fireActionClicked(checksumAction);

      expect(putModelAction).toHaveBeenCalledWith(
        model.modelClass,
        model.recordIdentifier,
        checksumAction.value,
      );
    });

    describe('when action succeeds', () => {
      const updatedModel = {
        ...rawModel,
        checksum_information: {
          ...rawModel.checksum_information,
          last_checksum: '2025-10-28T07:40:22.061Z',
        },
      };

      beforeEach(async () => {
        putModelAction.mockResolvedValue({ data: updatedModel });

        fireActionClicked(checksumAction);
        await waitForPromises();
      });

      it('updates item', () => {
        const lastChecksum = findGeoListItem()
          .props('timeAgoArray')
          .find((timeAgo) => timeAgo.label === 'Last checksum').dateString;

        expect(lastChecksum).toBe(updatedModel.checksum_information.last_checksum);
      });

      it('stops loading state', () => {
        expect(findGeoListItem().props('actionsArray')[0].loading).toBe(false);
      });

      it('shows toast', () => {
        expect(showToast).toHaveBeenCalledWith(checksumAction.successMessage);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when action fails', () => {
      const error = new Error('Failed to load models');

      beforeEach(async () => {
        putModelAction.mockRejectedValue(error);

        fireActionClicked(checksumAction);
        await waitForPromises();
      });

      it('creates alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: checksumAction.errorMessage,
          captureError: true,
          error,
        });
      });

      it('stops loading state', () => {
        expect(findGeoListItem().props('actionsArray')[0].loading).toBe(false);
      });
    });
  });

  describe.each`
    checksumState  | expectedStatus                          | expectedLabel
    ${'pending'}   | ${VERIFICATION_STATUS_STATES.PENDING}   | ${VERIFICATION_STATUS_LABELS.PENDING}
    ${'started'}   | ${VERIFICATION_STATUS_STATES.STARTED}   | ${VERIFICATION_STATUS_LABELS.STARTED}
    ${'succeeded'} | ${VERIFICATION_STATUS_STATES.SUCCEEDED} | ${VERIFICATION_STATUS_LABELS.SUCCEEDED}
    ${'failed'}    | ${VERIFICATION_STATUS_STATES.FAILED}    | ${VERIFICATION_STATUS_LABELS.FAILED}
    ${'disabled'}  | ${VERIFICATION_STATUS_STATES.DISABLED}  | ${VERIFICATION_STATUS_LABELS.DISABLED}
    ${undefined}   | ${VERIFICATION_STATUS_STATES.UNKNOWN}   | ${VERIFICATION_STATUS_LABELS.UNKNOWN}
  `('when checkSum state is $checksumState', ({ checksumState, expectedStatus, expectedLabel }) => {
    it('passes correct status props to GeoListItem', () => {
      createComponent({
        initialItem: {
          ...model,
          checksumInformation: { ...model.checksumInformation, checksumState },
        },
      });

      expect(findGeoListItem().props('statusArray')).toEqual([
        {
          tooltip: `Checksum: ${expectedStatus.title}`,
          icon: expectedStatus.icon,
          variant: expectedStatus.variant,
          label: expectedLabel,
        },
      ]);
    });
  });

  describe('when fileSize is provided', () => {
    it('renders size', () => {
      createComponent({ initialItem: { ...model, fileSize: 1024 } });

      expect(findGeoListItem().text()).toContain('Storage: 1.00 KiB');
    });
  });

  describe('when fileSize is 0', () => {
    it('renders size"', () => {
      createComponent({ initialItem: { ...model, fileSize: 0 } });

      expect(findGeoListItem().text()).toContain('Storage: 0 B');
    });
  });

  describe('when fileSize is not provided', () => {
    it('renders size as "Unknown"', () => {
      createComponent({ initialItem: { ...model, fileSize: null } });

      expect(findGeoListItem().text()).toContain('Storage: Unknown');
    });
  });
});

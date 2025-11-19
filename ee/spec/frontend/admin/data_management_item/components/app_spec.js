import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AdminDataManagementItemApp from 'ee/admin/data_management_item/components/app.vue';
import ChecksumInfo from 'ee/admin/data_management_item/components/checksum_info.vue';
import { getModel } from 'ee/api/data_management_api';
import waitForPromises from 'helpers/wait_for_promises';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createAlert } from '~/alert';

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');

describe('AdminDataManagementItemApp', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });
  const modelDisplayName = `${model.modelClass}/${model.recordIdentifier}`;

  const defaultProps = {
    modelClass: model.modelClass,
    modelId: model.recordIdentifier.toString(),
    modelName: model.modelClass,
  };

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementItemApp, {
      propsData: defaultProps,
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findChecksumInfo = () => wrapper.findComponent(ChecksumInfo);

  it('renders page heading', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe(modelDisplayName);
  });

  it('renders loading icon', () => {
    createComponent();

    expect(findGlLoadingIcon().exists()).toBe(true);
  });

  it('loads model', () => {
    createComponent();

    expect(getModel).toHaveBeenCalledWith(defaultProps.modelName, defaultProps.modelId);
  });

  describe('when loading model succeeds', () => {
    beforeEach(async () => {
      getModel.mockResolvedValue({ data: model });
      createComponent();
      await waitForPromises();
    });

    it('renders model details', () => {
      expect(findChecksumInfo().props('details')).toEqual(model.checksumInformation);
    });

    it('does not create alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('hides loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    describe('when model has no checksumInformation', () => {
      beforeEach(async () => {
        getModel.mockResolvedValue({ data: { ...model, checksumInformation: null } });
        createComponent();
        await waitForPromises();
      });

      it('passes empty object to ChecksumInfo', () => {
        expect(findChecksumInfo().props('details')).toEqual({});
      });
    });
  });

  describe('when loading model failed', () => {
    const error = new Error('Failed to load models');

    beforeEach(async () => {
      getModel.mockRejectedValue(error);
      createComponent();
      await waitForPromises();
    });

    it('creates alert', () => {
      const message = `There was an error fetching ${modelDisplayName}. Please refresh the page and try again.`;
      expect(createAlert).toHaveBeenCalledWith({ message, captureError: true, error });
    });

    it('hides loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    it('does not render ChecksumInfo', () => {
      expect(findChecksumInfo().exists()).toBe(false);
    });
  });
});

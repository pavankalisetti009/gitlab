import { GlCollapsibleListbox, GlSegmentedControl } from '@gitlab/ui';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TasksByTypeFilters from 'ee/analytics/cycle_analytics/components/tasks_by_type/filters.vue';
import {
  TASKS_BY_TYPE_SUBJECT_ISSUE,
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
  TASKS_BY_TYPE_FILTERS,
} from 'ee/analytics/cycle_analytics/constants';
import createStore from 'ee/analytics/cycle_analytics/store';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert, VARIANT_INFO } from '~/alert';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { groupLabels, groupLabelNames } from '../../mock_data';

Vue.use(Vuex);

jest.mock('~/alert');

describe('TasksByTypeFilters', () => {
  let wrapper = null;

  const mockGroupLabelsRequest = ({ status = HTTP_STATUS_OK, results = groupLabels } = {}) =>
    new MockAdapter(axios).onGet().reply(status, results);

  const createWrapper = async ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(TasksByTypeFilters, {
      store: createStore(),
      propsData: {
        selectedLabelNames: groupLabelNames,
        subjectFilter: TASKS_BY_TYPE_SUBJECT_ISSUE,
        ...props,
      },
    });

    await waitForPromises();
  };

  const findSubjectFilters = () => wrapper.findComponent(GlSegmentedControl);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectedLabelsCount = () => wrapper.findByTestId('selected-labels-count');

  describe('with default props', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper();
    });

    it('has the issue subject set by default', () => {
      expect(findSubjectFilters().props().checked).toBe(TASKS_BY_TYPE_SUBJECT_ISSUE);
    });

    it('emits the `update-filter` event when a subject filter is clicked', () => {
      expect(wrapper.emitted('update-filter')).toBeUndefined();

      findSubjectFilters().vm.$emit('input', TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);

      expect(wrapper.emitted('update-filter').length).toBe(1);
      expect(wrapper.emitted('update-filter')[0]).toEqual([
        {
          filter: TASKS_BY_TYPE_FILTERS.SUBJECT,
          value: TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
        },
      ]);
    });

    it('emits the `update-filter` event when a label is selected', () => {
      expect(wrapper.emitted('update-filter')).toBeUndefined();

      findCollapsibleListbox().vm.$emit('select', groupLabels[0].title);

      expect(wrapper.emitted('update-filter').length).toBe(1);
      expect(wrapper.emitted('update-filter')[0]).toEqual([
        { filter: TASKS_BY_TYPE_FILTERS.LABEL, value: groupLabels[0] },
      ]);
    });

    it('renders the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().text()).toBe('3 labels selected (15 max)');
    });
  });

  describe('with no labels selected', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { selectedLabelNames: [] } });
    });

    it('does not render the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().exists()).toBe(false);
    });
  });

  describe('with one label selected', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { selectedLabelNames: [groupLabels[0].title] } });
    });

    it('renders the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().text()).toBe('1 label selected (15 max)');
    });
  });

  describe('with maximum labels selected', () => {
    const selectedLabelNames = [groupLabels[0].title, groupLabels[1].title];

    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { maxLabels: 2, selectedLabelNames } });
    });

    it('should not allow adding a label', () => {
      findCollapsibleListbox().vm.$emit('select', [...selectedLabelNames, groupLabels[2].title]);
      expect(wrapper.emitted('update-filter')).toBeUndefined();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Only 2 labels can be selected at this time',
        variant: VARIANT_INFO,
      });
    });

    it('should allow removing a label', () => {
      findCollapsibleListbox().vm.$emit('select', [groupLabels[0].title]);
      expect(wrapper.emitted('update-filter').length).toBe(1);
      expect(wrapper.emitted('update-filter')[0]).toEqual([
        { filter: TASKS_BY_TYPE_FILTERS.LABEL, value: groupLabels[1] },
      ]);
    });
  });

  describe('with no default labels', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      createWrapper({ state: { defaultGroupLabels: [] } });
    });

    it('will show loading state while request is pending', () => {
      expect(findCollapsibleListbox().props().loading).toBe(true);
    });

    describe('once labels are loaded', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().loading).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(groupLabels.length);
      });
    });
  });

  describe('default labels fail to load', () => {
    beforeEach(() => {
      mockGroupLabelsRequest({ status: HTTP_STATUS_NOT_FOUND });
      return createWrapper({ state: { defaultGroupLabels: [] } });
    });

    it('stops the loading state', () => {
      expect(findCollapsibleListbox().props().loading).toBe(false);
    });

    it('emits an error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching label data for the selected group',
      });
    });
  });

  describe('when searching', () => {
    const results = groupLabels.slice(0, 1);

    beforeEach(async () => {
      mockGroupLabelsRequest({ results });
      await createWrapper();

      findCollapsibleListbox().vm.$emit('search', 'query');
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once request finishes', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(results.length);
      });
    });
  });
});

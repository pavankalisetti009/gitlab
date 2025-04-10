import { shallowMount } from '@vue/test-utils';
import { orderBy } from 'lodash';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardFilteredSearch from 'ee/boards/components/board_filtered_search.vue';
import IssueBoardFilteredSearch from 'ee/boards/components/issue_board_filtered_search.vue';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import issueBoardFilters from 'ee/boards/issue_board_filters';
import { mockTokens } from '../mock_data';

Vue.use(VueApollo);
jest.mock('ee/boards/issue_board_filters');

describe('IssueBoardFilter', () => {
  let wrapper;

  const createComponent = ({ hasCustomFieldsFeature = false } = {}) => {
    const customFieldsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        namespace: {
          id: 'gid://gitlab/Group/1',
          customFields: {
            count: 2,
            nodes: [
              {
                id: 'gid://gitlab/CustomField/12345',
                name: 'A multi select thing',
                fieldType: 'MULTI_SELECT',
                workItemTypes: [
                  {
                    id: 'gid://gitlab/WorkItemTypes/1',
                    name: 'Issue',
                  },
                ],
              },
            ],
          },
        },
      },
    });

    wrapper = shallowMount(IssueBoardFilteredSearch, {
      propsData: {
        boardId: 'gid://gitlab/Board/1',
        filters: {},
      },
      apolloProvider: createMockApollo([[namespaceCustomFieldsQuery, customFieldsQueryHandler]]),
      provide: {
        isSignedIn: true,
        releasesFetchPath: '/releases',
        fullPath: 'gitlab-org',
        isGroupBoard: true,
        epicFeatureAvailable: true,
        iterationFeatureAvailable: true,
        healthStatusFeatureAvailable: true,
        hasCustomFieldsFeature,
      },
    });
  };

  let fetchLabelsSpy;
  let fetchIterationsSpy;
  beforeEach(() => {
    fetchLabelsSpy = jest.fn();
    fetchIterationsSpy = jest.fn();

    issueBoardFilters.mockReturnValue({
      fetchLabels: fetchLabelsSpy,
      fetchIterations: fetchIterationsSpy,
    });
  });

  describe('default', () => {
    beforeEach(() => {});

    it('finds BoardFilteredSearch', () => {
      createComponent();
      expect(wrapper.findComponent(BoardFilteredSearch).exists()).toBe(true);
    });

    it('passes the correct tokens to BoardFilteredSearch including epics', () => {
      createComponent();
      const tokens = mockTokens({
        fetchLabels: fetchLabelsSpy,
        fetchIterations: fetchIterationsSpy,
      });

      expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
        orderBy(tokens, ['title']),
      );
    });

    it('passes custom fields to BoardFilteredSearch', async () => {
      const tokens = mockTokens({
        fetchLabels: fetchLabelsSpy,
        fetchIterations: fetchIterationsSpy,
        hasCustomFieldsFeature: true,
      });

      createComponent({ hasCustomFieldsFeature: true });

      await waitForPromises();

      expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
        orderBy(tokens, ['title']),
      );
    });
  });
});

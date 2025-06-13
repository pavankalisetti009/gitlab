import { GlEmptyState, GlTableLite, GlKeysetPagination } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import WorkflowsList from 'ee/ai/duo_agents_platform/components/common/workflows_list.vue';
import { mockWorkflows } from '../../../mocks';

describe('WorkflowsList', () => {
  let wrapper;

  const createWrapper = (props = {}, mountFn = mount) => {
    wrapper = mountFn(WorkflowsList, {
      propsData: {
        workflows: mockWorkflows,
        workflowsPageInfo: {},
        emptyStateIllustrationPath: 'illustrations/empty-state/empty-pipeline-md.svg',
        ...props,
      },
      stubs: {
        GlTableLite,
      },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('and there are no workflows', () => {
      beforeEach(async () => {
        await createWrapper({ workflows: [] });
      });

      it('renders the emptyState', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyState().props()).toMatchObject({
          title: 'No Agent runs yet',
          description: 'New Agent runs will appear here.',
          svgPath: 'illustrations/empty-state/empty-pipeline-md.svg',
        });
      });

      it('does not render the table', () => {
        expect(findTable().exists()).toBe(false);
      });
    });

    describe('when there are workflows', () => {
      it('renders the table component', () => {
        expect(findTable().exists()).toBe(true);
      });

      it('passes the correct fields to the table', () => {
        const expectedFields = [
          { key: 'id', label: 'ID' },
          { key: 'humanStatus', label: 'Status' },
          { key: 'updatedAt', label: 'Last updated' },
          { key: 'goal', label: 'Prompt' },
        ];

        expect(findTable().props('fields')).toEqual(expectedFields);
      });

      it('renders workflows as items to the table', () => {
        expect(findTable().html()).toContain(mockWorkflows[0].goal);
        expect(findTable().html()).toContain(mockWorkflows[1].goal);
      });
    });
  });

  describe('keyset pagination controls', () => {
    describe('when there is no pagination data', () => {
      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: {},
        });
      });

      it('does not render pagination controls', () => {
        expect(findKeysetPagination().isVisible()).toBe(false);
      });
    });
    describe('when there is pagination data', () => {
      const paginationData = {
        startCursor: 'start',
        endCursor: 'end',
        hasNextPage: true,
        hasPreviousPage: false,
      };

      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: paginationData,
        });
      });

      it('renders pagination controls', () => {
        expect(findKeysetPagination().isVisible()).toBe(true);
      });

      it('binds the correct page info to pagination controls', () => {
        expect(findKeysetPagination().props()).toMatchObject(paginationData);
      });

      describe('when clicking on the next page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('next');
        });

        it('emit next-page', () => {
          expect(wrapper.emitted('next-page')).toHaveLength(1);
        });
      });

      describe('when clicking on the previous page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('prev');
        });

        it('emit prev-page', () => {
          expect(wrapper.emitted('prev-page')).toHaveLength(1);
        });
      });
    });
  });
});

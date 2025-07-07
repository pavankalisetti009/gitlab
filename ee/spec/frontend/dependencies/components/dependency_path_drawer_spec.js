import {
  GlDrawer,
  GlTruncateText,
  GlBadge,
  GlAlert,
  GlCollapsibleListbox,
  GlSkeletonLoader,
  GlKeysetPagination,
} from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getDependencyPaths from 'ee/dependencies/graphql/dependency_paths.query.graphql';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { NAMESPACE_PROJECT, NAMESPACE_GROUP } from 'ee/dependencies/constants';
import { getDependencyPathsResponse, defaultDependencyPaths } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

describe('DependencyPathDrawer component', () => {
  let wrapper;
  let mockApollo;
  let responseHandler;

  const defaultProps = {
    component: {
      name: 'activerecord',
      version: '5.0.0',
    },
    occurrenceId: 1,
  };
  const defaultGroup = 'some-group';
  const defaultProject = 'some-project';

  const createComponent = ({
    props,
    namespaceType = NAMESPACE_PROJECT,
    resolver = jest.fn().mockResolvedValue(getDependencyPathsResponse()),
  } = {}) => {
    responseHandler = resolver;
    mockApollo = createMockApollo([[getDependencyPaths, responseHandler]]);

    wrapper = shallowMountExtended(DependencyPathDrawer, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlDrawer: stubComponent(GlDrawer, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
      provide: {
        namespaceType,
        projectFullPath: defaultProject,
        groupFullPath: defaultGroup,
      },
    });

    return waitForPromises();
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findTitle = () => wrapper.findByTestId('dependency-path-drawer-title');
  const findHeader = () => wrapper.findByTestId('dependency-path-drawer-header');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findProjectList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAllListItem = () => wrapper.findAll('li');
  const getTruncateText = (index) => findAllListItem().at(index).findComponent(GlTruncateText);
  const getBadge = (index) => findAllListItem().at(index).findComponent(GlBadge);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  afterEach(() => {
    mockApollo = null;
  });

  describe('default', () => {
    it('configures the drawer with header height and z-index', () => {
      const mockHeaderHeight = '50px';

      getContentWrapperHeight.mockReturnValue(mockHeaderHeight);
      createComponent();

      expect(findDrawer().props()).toMatchObject({
        headerHeight: mockHeaderHeight,
        zIndex: DRAWER_Z_INDEX,
      });
    });

    it('the drawer is not shown', () => {
      createComponent({ props: { showDrawer: false } });
      expect(findDrawer().props('open')).toBe(false);
    });

    it('the drawer is shown', () => {
      createComponent({ props: { showDrawer: true } });
      expect(findDrawer().props('open')).toBe(true);
    });

    it('has the drawer title', () => {
      createComponent({ props: { showDrawer: false } });
      expect(findTitle().text()).toEqual('Dependency paths');
    });
  });

  describe('with header section', () => {
    it('shows header text when component exists', () => {
      createComponent({ props: { showDrawer: true } });

      const { name, version } = defaultProps.component;
      expect(findHeader().text()).toBe(`Component: ${name} ${version}`);
    });
  });

  describe('with dependency paths section', () => {
    it('renders the correct length of dependency path items', async () => {
      await createComponent();

      expect(findAllListItem()).toHaveLength(defaultDependencyPaths.nodes.length);
    });

    it('renders the truncate text with the correct props', async () => {
      await createComponent();

      expect(getTruncateText(0).props()).toMatchObject({
        mobileLines: 3,
        toggleButtonProps: {
          class: 'gl-text-subtle gl-mt-3',
        },
      });
    });

    it('renders the paths text in the correct format', async () => {
      await createComponent();

      const index = 0;
      const { path } = defaultDependencyPaths.nodes[index];
      const text = path.map(({ name, version }) => `${name} @${version}`).join(' / ');
      expect(getTruncateText(index).text()).toBe(text);
    });
  });

  describe('with circular dependency badge', () => {
    it('renders the badge with the correct prop and text', async () => {
      const cyclicDependencyPath = {
        ...defaultDependencyPaths,
        nodes: [
          {
            ...defaultDependencyPaths.nodes[0],
            isCyclic: true,
          },
        ],
      };
      const cyclicResponseHandler = jest
        .fn()
        .mockResolvedValue(getDependencyPathsResponse(cyclicDependencyPath));
      await createComponent({ resolver: cyclicResponseHandler });

      expect(getBadge(0).props('variant')).toBe('warning');
      expect(getBadge(0).text()).toBe('circular dependency');
    });

    it('does not render the badge', async () => {
      await createComponent();

      expect(getBadge(0).exists()).toBe(false);
    });
  });

  describe('query', () => {
    it('is loading when fetching dependency paths', async () => {
      createComponent();
      expect(findSkeletonLoader().exists()).toBe(true);

      await waitForPromises();
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('passes the correct variables', async () => {
      await createComponent();

      expect(responseHandler).toHaveBeenCalledWith({
        fullPath: defaultProject,
        occurrence: `gid://gitlab/Sbom::Occurrence/${defaultProps.occurrenceId}`,
        before: null,
        after: null,
      });
    });

    it('skips query when occurrenceId is not available', async () => {
      await createComponent({
        props: { occurrenceId: null },
        resolver: jest.fn().mockResolvedValue(getDependencyPathsResponse()),
      });

      expect(responseHandler).not.toHaveBeenCalled();
    });
  });

  describe('pagination', () => {
    const createPaginationResponse = (pageInfo = {}) => {
      const paginationDependencyPaths = {
        ...defaultDependencyPaths,
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          ...pageInfo,
        },
      };
      return getDependencyPathsResponse(paginationDependencyPaths);
    };

    describe('when pagination is not needed', () => {
      beforeEach(async () => {
        const noPaginationResponse = createPaginationResponse();
        await createComponent({
          resolver: jest.fn().mockResolvedValue(noPaginationResponse),
        });
      });

      it('does not show pagination component', () => {
        expect(findPagination().exists()).toBe(false);
      });
    });

    describe('when pagination is available', () => {
      beforeEach(async () => {
        const paginationResponse = createPaginationResponse({
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
        });
        await createComponent({
          resolver: jest.fn().mockResolvedValue(paginationResponse),
        });
      });

      it('shows pagination component with correct props', () => {
        const pagination = findPagination();

        expect(pagination.exists()).toBe(true);
        expect(pagination.props()).toMatchObject({
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
        });
      });

      it('calls nextPage with correct cursor when next is clicked', async () => {
        const pagination = findPagination();
        const endCursor = 'end-cursor';

        pagination.vm.$emit('next', endCursor);
        await waitForPromises();

        expect(responseHandler).toHaveBeenCalledWith({
          fullPath: defaultProject,
          occurrence: `gid://gitlab/Sbom::Occurrence/${defaultProps.occurrenceId}`,
          after: endCursor,
          before: null,
        });
      });

      it('calls prevPage with correct cursor when prev is clicked', async () => {
        const pagination = findPagination();
        const startCursor = 'start-cursor';

        pagination.vm.$emit('prev', startCursor);
        await waitForPromises();

        expect(responseHandler).toHaveBeenCalledWith({
          fullPath: defaultProject,
          occurrence: `gid://gitlab/Sbom::Occurrence/${defaultProps.occurrenceId}`,
          after: null,
          before: startCursor,
        });
      });
    });

    describe('pagination reset', () => {
      let paginationResponse;
      beforeEach(async () => {
        paginationResponse = createPaginationResponse({
          hasNextPage: true,
          endCursor: 'end-cursor',
        });
        await createComponent({
          resolver: jest.fn().mockResolvedValue(paginationResponse),
        });
      });

      it('resets pagination when occurrenceId changes', async () => {
        // First, navigate to next page
        const pagination = findPagination();
        pagination.vm.$emit('next', 'end-cursor');
        await waitForPromises();

        // Verify cursor was set
        expect(responseHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: 'end-cursor',
            before: null,
          }),
        );

        // Change occurrenceId
        wrapper.setProps({ occurrenceId: 2 });
        await waitForPromises();

        // Verify pagination was reset (no cursor parameters)
        expect(responseHandler).toHaveBeenCalledWith({
          fullPath: defaultProject,
          occurrence: `gid://gitlab/Sbom::Occurrence/2`,
          after: null,
          before: null,
        });
      });
    });
  });

  describe('with dropdown', () => {
    const items = [
      {
        name: 'Project 1',
        full_path: 'group-1/project-1',
        has_dependency_paths: true,
        occurrence_id: 1,
      },
      {
        name: 'Project 2',
        full_path: 'group-1/project-2',
        has_dependency_paths: true,
        occurrence_id: 2,
      },
      {
        name: 'Project 3',
        full_path: 'group-1/group-child/project-3',
        has_dependency_paths: true,
        occurrence_id: 3,
      },
    ];

    const createDropdownItems = (item) =>
      item.map(({ name, full_path: fullPath, occurrence_id: value }) => ({
        value,
        text: name,
        fullPath,
      }));

    beforeEach(async () => {
      await createComponent({
        props: {
          showDrawer: true,
          dropdownItems: createDropdownItems(items),
        },
        namespaceType: NAMESPACE_GROUP,
      });
    });

    it('renders the first item and its path', () => {
      const firstLocation = items[0];
      const { occurrence_id } = firstLocation;

      expect(findProjectList().props('selected')).toBe(occurrence_id);
    });

    it('resets selected item in dropdown when dropdownItems change', async () => {
      const newItems = [
        {
          value: 5,
          text: 'Project 5',
          fullPath: 'group-1/project-5',
        },
      ];

      wrapper.setProps({ dropdownItems: newItems });
      await nextTick();

      expect(findProjectList().props('items')[0].value).toBe(newItems[0].value);
    });

    describe('query', () => {
      it('passes full path and occurrence of selected item', () => {
        const firstItem = items[0];
        expect(responseHandler).toHaveBeenCalledWith({
          fullPath: firstItem.full_path,
          occurrence: `gid://gitlab/Sbom::Occurrence/${firstItem.occurrence_id}`,
          before: null,
          after: null,
        });
      });

      it('queries again when selected item changes', async () => {
        const secondItem = items[1];
        findProjectList().vm.$emit('select', secondItem.occurrence_id);
        await waitForPromises();
        expect(responseHandler).toHaveBeenCalledTimes(2);
        expect(responseHandler).toHaveBeenCalledWith({
          fullPath: secondItem.full_path,
          occurrence: `gid://gitlab/Sbom::Occurrence/${secondItem.occurrence_id}`,
          before: null,
          after: null,
        });
      });
    });
  });

  describe('drawer footer warning', () => {
    it('displays the warning message when limitExceeded', () => {
      createComponent({ props: { limitExceeded: true } });

      const alert = findAlert();

      expect(alert.props()).toMatchObject({ variant: 'warning' });
      expect(alert.text()).toBe(
        'Resolve the vulnerability in these dependencies to see additional paths. GitLab shows a maximum of 20 dependency paths per vulnerability.',
      );
    });

    it('does not display the warning message by default', () => {
      createComponent();

      expect(findAlert().exists()).toBe(false);
    });
  });
});

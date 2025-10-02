import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { file } from 'jest/ide/helpers';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import FileIcon from '~/vue_shared/components/file_icon.vue';
import FileRow from '~/vue_shared/components/file_row.vue';
import FileHeader from '~/vue_shared/components/file_row_header.vue';

const scrollIntoViewMock = jest.fn();
HTMLElement.prototype.scrollIntoView = scrollIntoViewMock;

describe('File row component', () => {
  let wrapper;

  function createComponent(propsData, $router = undefined) {
    wrapper = shallowMount(FileRow, {
      propsData,
      mocks: {
        $router,
      },
    });
  }

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  it('renders name', () => {
    const fileName = 't4';
    createComponent({
      file: file(fileName),
      level: 0,
    });

    const name = wrapper.find('.file-row-name');

    expect(name.text().trim()).toEqual(fileName);
  });

  it('renders as button', () => {
    createComponent({
      file: file('t4'),
      level: 0,
    });
    expect(wrapper.find('button').exists()).toBe(true);
  });

  it('renders the full path as title', () => {
    const filePath = 'path/to/file/with a very long folder name/';
    const fileName = 'foo.txt';

    createComponent({
      file: {
        name: fileName,
        isHeader: false,
        tree: [
          {
            parentPath: filePath,
          },
        ],
      },
      level: 1,
    });

    expect(wrapper.element.title.trim()).toEqual('path/to/file/with a very long folder name/');
  });

  it('does not render a title attribute if no tree present', () => {
    createComponent({
      file: file('f1.txt'),
      level: 0,
    });

    expect(wrapper.element.title.trim()).toEqual('');
  });

  it('emits toggleTreeOpen on tree click', () => {
    const fileName = 't3';
    createComponent({
      file: {
        ...file(fileName),
        type: 'tree',
      },
      level: 0,
    });

    wrapper.element.click();

    expect(wrapper.emitted('toggleTreeOpen')[0][0]).toEqual(fileName);
  });

  it('emits clickTree on tree click with file path', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    const fileName = 'folder';
    const filePath = 'path/to/folder';
    createComponent({ file: { ...file(fileName), type: 'tree', path: filePath }, level: 0 });

    wrapper.element.click();

    expect(wrapper.emitted('clickTree')[0][0]).toEqual(filePath);
    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_file_tree_browser_on_repository_page',
      {},
      undefined,
    );
  });

  it('emits clickFile on blob click', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    const fileName = 't3';
    const fileProp = {
      ...file(fileName),
      type: 'blob',
    };
    createComponent({
      file: fileProp,
      level: 1,
    });

    wrapper.element.click();

    expect(wrapper.emitted('clickFile')[0][0]).toEqual(fileProp);
    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_file_tree_browser_on_repository_page',
      {},
      undefined,
    );
  });

  it('calls scrollIntoView if made active', () => {
    createComponent({
      file: {
        ...file(),
        type: 'blob',
        active: false,
      },
      level: 0,
    });

    wrapper.setProps({
      file: { ...wrapper.props('file'), active: true },
    });

    return nextTick().then(() => {
      expect(scrollIntoViewMock).toHaveBeenCalled();
    });
  });

  it('does not call scrollIntoView for Show more button', () => {
    const path = '/project/test.js';
    const router = { currentRoute: { path } };
    createComponent({ file: { path, isShowMore: true }, level: 0 }, router);

    expect(scrollIntoViewMock).not.toHaveBeenCalled();
  });

  it('renders header for file', () => {
    createComponent({
      file: {
        isHeader: true,
        path: 'app/assets',
        tree: [],
      },
      level: 0,
    });

    expect(wrapper.findComponent(FileHeader).exists()).toBe(true);
  });

  it('matches the current route against encoded file URL', () => {
    const fileName = 'with space';
    createComponent(
      {
        file: { ...file(fileName), url: `/${fileName}` },
        level: 0,
      },
      {
        currentRoute: {
          path: `/project/${fileName}`,
        },
      },
    );

    expect(wrapper.vm.hasUrlAtCurrentRoute()).toBe(true);
  });

  it('render with the correct file classes prop', () => {
    createComponent({
      file: {
        ...file(),
      },
      level: 0,
      fileClasses: '!gl-font-bold',
    });

    expect(wrapper.find('.file-row-name').classes()).toContain('!gl-font-bold');
  });

  it('renders submodule icon', () => {
    const submodule = true;

    createComponent({
      file: {
        ...file(),
        submodule,
      },
      level: 0,
    });

    expect(wrapper.findComponent(FileIcon).props('submodule')).toBe(submodule);
  });

  it('renders link icon', () => {
    createComponent({
      file: {
        ...file(),
        linked: true,
      },
      level: 0,
    });

    expect(wrapper.findComponent(GlIcon).props('name')).toBe('link');
  });

  describe('ARIA tree view pattern', () => {
    const createTreeItem = (fileProps = {}, level = 0) => {
      createComponent({
        file: { ...file('test.js'), ...fileProps },
        level,
      });
      return wrapper.find('button');
    };

    it('renders treeitem role for files and folders', () => {
      const button = createTreeItem();
      expect(button.attributes('role')).toBe('treeitem');
    });

    it.each`
      level | expectedAriaLevel
      ${0}  | ${'1'}
      ${2}  | ${'3'}
    `('sets aria-level=$expectedAriaLevel when level=$level', ({ level, expectedAriaLevel }) => {
      const button = createTreeItem({}, level);
      expect(button.attributes('aria-level')).toBe(expectedAriaLevel);
    });

    it('does not render aria-setsize and aria-posinset (handled by parent components)', () => {
      const button = createTreeItem({ ariaSetSize: 5, ariaPosInSet: 3 });
      expect(button.attributes('aria-setsize')).toBeUndefined();
      expect(button.attributes('aria-posinset')).toBeUndefined();
    });

    describe('folder-specific attributes', () => {
      it.each`
        opened   | expectedExpanded
        ${true}  | ${'true'}
        ${false} | ${'false'}
      `(
        'sets aria-expanded=$expectedExpanded when folder is opened=$opened',
        ({ opened, expectedExpanded }) => {
          const button = createTreeItem({ type: 'tree', opened });
          expect(button.attributes('aria-expanded')).toBe(expectedExpanded);
        },
      );

      it('does not set aria-expanded for files', () => {
        const button = createTreeItem({ type: 'blob' });
        expect(button.attributes('aria-expanded')).toBeUndefined();
      });
    });

    it.each`
      type      | name         | expectedLabel
      ${'tree'} | ${'src'}     | ${'src'}
      ${'blob'} | ${'test.js'} | ${'test.js'}
    `('sets aria-label="$expectedLabel" for $type', ({ type, name, expectedLabel }) => {
      const button = createTreeItem({ type, name });
      expect(button.attributes('aria-label')).toBe(expectedLabel);
    });
  });

  describe('Show more button', () => {
    const findShowMoreButton = () => wrapper.findComponent(GlButton);

    it('renders show more button when file.isShowMore is true', () => {
      createComponent({ file: { isShowMore: true, loading: false }, level: 0 });

      const showMoreButton = findShowMoreButton();
      expect(showMoreButton.props('category')).toBe('tertiary');
      expect(showMoreButton.props('loading')).toBe(false);
      expect(showMoreButton.text().trim()).toBe('Show more');
    });

    it('emits showMore event when show more button is clicked', () => {
      createComponent({ file: { isShowMore: true, loading: false }, level: 0 });

      findShowMoreButton().vm.$emit('click');

      expect(wrapper.emitted('showMore')).toHaveLength(1);
    });

    it('shows loading state on show more button', () => {
      createComponent({ file: { isShowMore: true, loading: true }, level: 0 });

      expect(findShowMoreButton().props('loading')).toBe(true);
    });
  });
});

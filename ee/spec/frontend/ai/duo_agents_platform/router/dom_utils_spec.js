import { updateActiveNavigation } from 'ee/ai/duo_agents_platform/router/dom_utils';

// Test constants
const CSS_CLASSES = {
  activeClass: 'super-sidebar-nav-item-current',
  activeIndicatorClass: 'active-indicator',
  hiddenClass: 'gl-hidden',
};

const SELECTORS = {
  superSidebar: '#super-sidebar',
};

// Mock factory functions
const createMockElement = (methods = {}) => ({
  classList: {
    add: jest.fn(),
    remove: jest.fn(),
    ...methods.classList,
  },
  querySelector: jest.fn(),
  ...methods,
});

const createMockNavItem = (indicator = null) => ({
  ...createMockElement(),
  querySelector: jest.fn().mockReturnValue(indicator),
});

const createMockSuperSidebar = (queryResults = {}) => ({
  querySelectorAll: jest.fn().mockImplementation((selector) => {
    return queryResults[selector] || [];
  }),
});

describe('updateActiveNavigation', () => {
  let mockSuperSidebar;
  let mockElements;

  const setupMockSuperSidebar = (config = {}) => {
    const { activeNavItems = [], activeIndicators = [], newNavItems = [] } = config;

    const queryResults = {
      [`.${CSS_CLASSES.activeClass}`]: activeNavItems,
      [`.${CSS_CLASSES.activeIndicatorClass}`]: activeIndicators,
    };

    // Add dynamic href-based queries
    if (newNavItems.length > 0) {
      // This will be set dynamically in tests
      mockSuperSidebar.querySelectorAll.mockImplementation((selector) => {
        if (selector.includes('[href*=')) {
          return newNavItems;
        }
        return queryResults[selector] || [];
      });
    } else {
      mockSuperSidebar = createMockSuperSidebar(queryResults);
    }
  };

  const setupDocumentMock = (superSidebarExists = true) => {
    jest.spyOn(document, 'querySelector').mockImplementation((selector) => {
      if (selector === SELECTORS.superSidebar) {
        return superSidebarExists ? mockSuperSidebar : null;
      }
      return null;
    });
  };

  beforeEach(() => {
    // Create reusable mock elements
    mockElements = {
      activeNavItems: [createMockElement(), createMockElement()],
      activeIndicators: [createMockElement(), createMockElement()],
      newIndicators: [createMockElement(), createMockElement()],
    };

    mockElements.newNavItems = [
      createMockNavItem(mockElements.newIndicators[0]),
      createMockNavItem(mockElements.newIndicators[1]),
    ];

    mockSuperSidebar = createMockSuperSidebar();
    setupDocumentMock();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('when super-sidebar element exists', () => {
    beforeEach(() => {
      setupMockSuperSidebar({
        activeNavItems: mockElements.activeNavItems,
        activeIndicators: mockElements.activeIndicators,
        newNavItems: mockElements.newNavItems,
      });
    });

    it('removes active class from current active nav items', () => {
      updateActiveNavigation('/test-href');

      mockElements.activeNavItems.forEach((item) => {
        expect(item.classList.remove).toHaveBeenCalledWith(CSS_CLASSES.activeClass);
      });
    });

    it('hides current active indicators', () => {
      updateActiveNavigation('/test-href');

      mockElements.activeIndicators.forEach((indicator) => {
        expect(indicator.classList.add).toHaveBeenCalledWith(CSS_CLASSES.hiddenClass);
      });
    });

    it('adds active class to new nav items matching href', () => {
      updateActiveNavigation('/test-href');

      expect(mockSuperSidebar.querySelectorAll).toHaveBeenCalledWith('[href*="/test-href"]');
      mockElements.newNavItems.forEach((item) => {
        expect(item.classList.add).toHaveBeenCalledWith(CSS_CLASSES.activeClass);
      });
    });

    it('shows indicators for new active nav items', () => {
      updateActiveNavigation('/test-href');

      mockElements.newNavItems.forEach((item, index) => {
        expect(item.querySelector).toHaveBeenCalledWith(`.${CSS_CLASSES.activeIndicatorClass}`);
        expect(mockElements.newIndicators[index].classList.remove).toHaveBeenCalledWith(
          CSS_CLASSES.hiddenClass,
        );
      });
    });

    it('handles href with special characters', () => {
      const specialHref = '/agents/test-agent-123';
      updateActiveNavigation(specialHref);

      expect(mockSuperSidebar.querySelectorAll).toHaveBeenCalledWith(`[href*="${specialHref}"]`);
    });

    describe('when no current active nav items exist', () => {
      beforeEach(() => {
        setupMockSuperSidebar({
          activeNavItems: [],
          activeIndicators: [],
          newNavItems: [mockElements.newNavItems[0]],
        });
      });

      it('does not attempt to remove classes from non-existent elements', () => {
        updateActiveNavigation('/test-href');

        mockElements.activeNavItems.forEach((item) => {
          expect(item.classList.remove).not.toHaveBeenCalled();
        });
      });

      it('still adds active class to new nav items', () => {
        updateActiveNavigation('/test-href');

        expect(mockElements.newNavItems[0].classList.add).toHaveBeenCalledWith(
          CSS_CLASSES.activeClass,
        );
      });
    });

    describe('when no current active indicators exist', () => {
      beforeEach(() => {
        setupMockSuperSidebar({
          activeNavItems: [mockElements.activeNavItems[0]],
          activeIndicators: [],
          newNavItems: [mockElements.newNavItems[0]],
        });
      });

      it('does not attempt to hide non-existent indicators', () => {
        updateActiveNavigation('/test-href');

        mockElements.activeIndicators.forEach((indicator) => {
          expect(indicator.classList.add).not.toHaveBeenCalled();
        });
      });
    });

    describe('when no new nav items match the href', () => {
      beforeEach(() => {
        setupMockSuperSidebar({
          activeNavItems: [mockElements.activeNavItems[0]],
          activeIndicators: [mockElements.activeIndicators[0]],
          newNavItems: [],
        });
      });

      it('still removes current active classes and hides indicators', () => {
        updateActiveNavigation('/non-matching-href');

        expect(mockElements.activeNavItems[0].classList.remove).toHaveBeenCalledWith(
          CSS_CLASSES.activeClass,
        );
        expect(mockElements.activeIndicators[0].classList.add).toHaveBeenCalledWith(
          CSS_CLASSES.hiddenClass,
        );
      });

      it('does not attempt to add classes to non-existent new nav items', () => {
        updateActiveNavigation('/non-matching-href');

        mockElements.newNavItems.forEach((item) => {
          expect(item.classList.add).not.toHaveBeenCalled();
        });
      });
    });

    describe('when new nav items exist but have no indicators', () => {
      beforeEach(() => {
        const navItemWithoutIndicator = createMockNavItem(null);
        setupMockSuperSidebar({
          activeNavItems: [],
          activeIndicators: [],
          newNavItems: [navItemWithoutIndicator],
        });
      });

      it('adds active class to nav items but does not attempt to show indicators', () => {
        expect(() => updateActiveNavigation('/test-href')).not.toThrow();
      });
    });
  });

  describe('when super-sidebar element does not exist', () => {
    beforeEach(() => {
      setupDocumentMock(false);
    });

    it('returns early without throwing an error', () => {
      expect(() => updateActiveNavigation('/test-href')).not.toThrow();
    });

    it('does not attempt to query for nav items', () => {
      updateActiveNavigation('/test-href');

      expect(mockSuperSidebar.querySelectorAll).not.toHaveBeenCalled();
    });
  });

  describe('edge cases', () => {
    beforeEach(() => {
      setupMockSuperSidebar({});
    });

    const edgeCaseHrefs = [
      { value: '', description: 'empty href' },
      { value: undefined, description: 'undefined href' },
      { value: null, description: 'null href' },
      { value: '/test"path', description: 'href with quotes' },
    ];

    it.each(edgeCaseHrefs)('handles $description', ({ value }) => {
      expect(() => updateActiveNavigation(value)).not.toThrow();
      expect(mockSuperSidebar.querySelectorAll).toHaveBeenCalledWith(`[href*="${value}"]`);
    });
  });
});

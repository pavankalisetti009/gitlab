import { GlTableLite, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EventsTable from 'ee/usage_quotas/usage_billing/users/show/components/events_table.vue';
import UserDate from '~/vue_shared/components/user_date.vue';

describe('EventsTable', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockEvents = [
    {
      timestamp: '2023-12-01T10:30:00Z',
      eventType: 'Code Completion',
      location: {
        name: 'gitlab-org/gitlab',
        web_url: 'https://gitlab.com/gitlab-org/gitlab',
      },
      creditsUsed: 150,
    },
    {
      timestamp: '2023-12-01T09:15:00Z',
      eventType: 'Code Generation',
      location: {
        name: 'gitlab-org/gitlabhq',
        web_url: 'https://gitlab.com/gitlab-org/gitlabhq',
      },
      creditsUsed: 75,
    },
    {
      timestamp: '2023-12-01T08:45:00Z',
      eventType: 'Chat',
      location: null,
      creditsUsed: 25,
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = mountExtended(EventsTable, {
      propsData: {
        events: mockEvents,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().find('tbody').findAll('tr');
  const findFirstRowCells = () => findTableRows().at(0).findAll('td');

  describe('when events are provided', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the table with correct number of rows', () => {
      expect(findTableRows()).toHaveLength(mockEvents.length);
    });

    it('renders table with correct field headers', () => {
      const tableFields = findTable().props('fields');

      expect(tableFields).toEqual([
        { key: 'timestamp', label: 'Date/Time' },
        { key: 'eventType', label: 'Action' },
        { key: 'location', label: 'Location' },
        { key: 'creditsUsed', label: 'Credit amount' },
      ]);
    });

    describe('cells rendering', () => {
      /** @type {import('@vue/test-utils').WrapperArray,} */
      let firstRowCells;

      beforeEach(() => {
        firstRowCells = findFirstRowCells();
      });

      it('renders the date and time', () => {
        expect(firstRowCells.at(0).findComponent(UserDate).exists()).toBe(true);
        expect(firstRowCells.at(0).findComponent(UserDate).props('date')).toBe(
          mockEvents[0].timestamp,
        );
      });

      it('renders event type', () => {
        expect(firstRowCells.at(1).text()).toBe(mockEvents[0].eventType);
      });

      describe('location cell', () => {
        it('renders location', () => {
          const locationLink = firstRowCells.at(2).findComponent(GlLink);
          expect(locationLink.exists()).toBe(true);
          expect(locationLink.attributes('href')).toBe(mockEvents[0].location.web_url);
          expect(locationLink.text()).toBe(mockEvents[0].location.name);
        });

        it('renders nothing when location is null', () => {
          const thirdRowCells = findTableRows().at(2).findAll('td');
          const locationCell = thirdRowCells.at(2);

          expect(locationCell.findComponent(GlLink).exists()).toBe(false);
          expect(locationCell.text()).toBe('');
        });
      });

      it('renders GU amount', () => {
        expect(firstRowCells.at(3).text()).toBe(mockEvents[0].creditsUsed.toString());
      });
    });
  });

  describe('when no events are provided', () => {
    beforeEach(() => {
      createComponent({ events: [] });
    });

    it('renders table with no rows', () => {
      expect(findTableRows()).toHaveLength(0);
    });
  });
});

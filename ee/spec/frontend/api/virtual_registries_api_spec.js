import MockAdapter from 'axios-mock-adapter';
import * as VirtualRegistryApi from 'ee/api/virtual_registries_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

const dummyApiVersion = 'v3000';
const dummyUrlRoot = '/gitlab';

describe('VirtualRegistriesApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: dummyApiVersion,
      relative_url_root: dummyUrlRoot,
    };
    jest.spyOn(axios, 'get');
  });

  afterEach(() => {
    mock.restore();
  });

  describe('getMavenRegistriesList', () => {
    it('fetches the maven registries of the root group', () => {
      const requestPath = 'virtual_registries/packages/maven/registries';
      const namespaceId = 'flightjs';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/-/${requestPath}`;
      const expectedParams = {
        id: namespaceId,
      };
      const expectResponse = [
        {
          id: 4,
          name: 'app-test',
          description: 'app description',
          group_id: 283,
          created_at: '2025-04-29T13:06:01.609Z',
          updated_at: '2025-05-02T04:00:15.442Z',
        },
      ];
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectResponse);

      return VirtualRegistryApi.getMavenVirtualRegistriesList(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectResponse);
      });
    });
  });
});

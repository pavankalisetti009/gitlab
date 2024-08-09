import MockAdapter from 'axios-mock-adapter';
import * as UsersApi from 'ee/api/users_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('UsersApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('validatePasswordComplexity', () => {
    const expectedUrl = '/users/password/complexity';
    const params = { password: '_password_' };

    it('sends password parameter', async () => {
      jest.spyOn(axios, 'post');
      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

      const { data } = await UsersApi.validatePasswordComplexity(params.password);

      expect(data).toEqual([]);
      expect(axios.post).toHaveBeenCalledWith(expectedUrl, params);
    });
  });
});

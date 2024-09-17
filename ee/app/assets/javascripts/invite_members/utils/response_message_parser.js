import { s__ } from '~/locale';
import { responseFromSuccess as CeResponseFromSuccess } from '~/invite_members/utils/response_message_parser';

export function responseFromSuccess(response) {
  let usersWithWarning;
  let warningTitle;
  const { error, message } = CeResponseFromSuccess(response);

  if (response.data.queued_users) {
    usersWithWarning = response.data.queued_users;
    warningTitle = s__(
      'InviteMembersModal|Some requests have been sent for administrator approval',
    );
  }

  return { error, message, usersWithWarning, warningTitle };
}

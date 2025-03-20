# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::SourceUsers::ReassignService, feature_category: :importers do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:import_source_user) { create(:import_source_user, namespace: subgroup) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:assignee_user) { create(:user) }

  subject(:service) { described_class.new(import_source_user, assignee_user, current_user: current_user) }

  describe '#execute' do
    before_all do
      group.add_owner(current_user)
    end

    shared_examples 'an error response' do |desc, error:|
      it "returns #{desc} error", :aggregate_failures do
        expect(Notify).not_to receive(:import_source_user_reassign)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq(error)
      end
    end

    shared_examples 'success response' do
      it 'returns success', :aggregate_failures do
        expect(Notify).to receive_message_chain(:import_source_user_reassign, :deliver_later)

        result = service.execute

        expect(result).to be_success
        expect(result.payload.reload).to eq(import_source_user)
        expect(result.payload.reassign_to_user).to eq(assignee_user)
        expect(result.payload.reassigned_by_user).to eq(current_user)
        expect(result.payload.awaiting_approval?).to be(true)
      end
    end

    context 'for SSO enforcement requirements' do
      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when SSO enforcement is enabled for namespace' do
        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }

        context 'when assignee user account does not meet SSO enforcement requirements' do
          it_behaves_like 'an error response', 'invalid_assignee',
            error: 'You can assign only users with linked SAML and SCIM identities. ' \
              'Ensure the user has signed into GitLab through your SAML SSO provider and has an ' \
              'active SCIM identity for this group.'

          context 'when assignee user account with linked SAML, but SCIM identity is inactive' do
            let_it_be(:group_saml_identity) do
              create(:group_saml_identity, saml_provider: saml_provider, user: assignee_user)
            end

            let_it_be(:group_scim_identity) do
              create(:group_scim_identity, active: false, group: group, user: assignee_user)
            end

            it_behaves_like 'an error response', 'invalid_assignee',
              error: 'You can assign only users with linked SAML and SCIM identities. ' \
                'Ensure the user has signed into GitLab through your SAML SSO provider and has an ' \
                'active SCIM identity for this group.'
          end
        end

        context 'when assignee user account meets SSO enforcement requirements' do
          let_it_be(:group_saml_identity) do
            create(:group_saml_identity, saml_provider: saml_provider, user: assignee_user)
          end

          it_behaves_like 'success response'
        end
      end

      context 'when SSO enforcement is not enabled for namespace' do
        let!(:saml_provider) { create(:saml_provider, group: group, enforced_sso: false) }

        context 'when assignee user account does not meet SSO enforcement requirements' do
          it_behaves_like 'success response'
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe Emails::Projects do
  include EmailSpec::Matchers

  describe '#user_escalation_rule_deleted_email' do
    let(:rule) { create(:incident_management_escalation_rule, :with_user) }
    let(:user) { rule.user }
    let(:project) { rule.project }
    let(:recipient) { build(:user) }
    let(:elapsed_time) { (rule.elapsed_time_seconds / 60).to_s }

    subject { Notify.user_escalation_rule_deleted_email(user, project, [rule], recipient) }

    it 'has the correct email content', :aggregate_failures do
      is_expected.to have_subject("#{project.name} | User removed from escalation policy")
      is_expected.to have_body_text(user.name)
      is_expected.to have_body_text(user.username)
      is_expected.to have_body_text('was removed from the following escalation policies')
      is_expected.to have_body_text(rule.policy.name)
      is_expected.to have_body_text(elapsed_time)
      is_expected.to have_body_text(rule.status.to_s)
      is_expected.to have_body_text("Please review the updated escalation policies for")
      is_expected.to have_body_text(project.name)
      is_expected.to have_body_text("It is recommended that you reach out to the current on-call responder to ensure continuity of on-call coverage")
    end
  end

  describe '#project_scheduled_for_deletion' do
    let_it_be(:user) { create(:user) }
    let_it_be(:frozen_time) { Time.new(2023, 10, 15, 12, 0, 0) }
    let_it_be(:project) { create(:project, marked_for_deletion_on: frozen_time) }

    let(:deletion_adjourned_period) { 7 }
    let(:deletion_date) { frozen_time.to_date + deletion_adjourned_period.days }

    before do
      stub_application_setting(deletion_adjourned_period: deletion_adjourned_period)
      allow_next_instance_of(Project) do |instance|
        allow(instance).to receive(:marked_for_deletion_on).and_return(frozen_time)
      end
    end

    subject { Notify.project_scheduled_for_deletion(user.id, project.id) }

    it 'has expected content', :aggregate_failures do
      is_expected.to have_subject("#{project.name} | Project scheduled for deletion")
      is_expected.to have_body_text(project.full_name)
      is_expected.to have_body_text(deletion_adjourned_period.to_s)
      is_expected.to have_body_text(deletion_date.strftime('%B %-d, %Y'))
    end
  end

  describe '#incident_escalation_fired_email' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }

    let!(:incident) { create(:issue, :incident, project: project) }
    let!(:escalation_status) { create(:incident_management_issuable_escalation_status, issue: incident) }

    subject do
      Notify.incident_escalation_fired_email(project, user, incident)
    end

    include_context 'gitlab email notification'

    it_behaves_like 'an email with X-GitLab headers containing project details'

    it 'has expected X-GitLab alert headers', :aggregate_failures do
      is_expected.to have_header('X-GitLab-NotificationReason', "incident_#{escalation_status.status_name}")
      is_expected.to have_header('X-GitLab-Incident-ID', /#{incident.id}/)
      is_expected.to have_header('X-GitLab-Incident-IID', /#{incident.iid}/)
    end

    it_behaves_like 'an email sent from GitLab'
    it_behaves_like 'it should not have Gmail Actions links'
    it_behaves_like 'a user cannot unsubscribe through footer link'

    it 'has expected subject' do
      is_expected.to have_subject("#{project.name} | Incident: #{incident.title}")
    end

    it 'has expected content' do
      is_expected.to have_body_text('Title:')
      is_expected.to have_body_text(incident.title)
    end

    context 'with description' do
      let!(:incident) { create(:issue, :incident, project: project, description: 'some descripition') }

      it 'has expected content' do
        is_expected.to have_body_text('Description:')
        is_expected.to have_body_text('some descripition')
      end
    end

    context 'with escalation status policy' do
      let!(:policy) { create(:incident_management_escalation_policy, project: project) }
      let!(:escalation_status) { create(:incident_management_issuable_escalation_status, issue: incident, policy: policy, escalations_started_at: Time.current) }

      it 'has expected content' do
        is_expected.to have_body_text('Escalation policy:')
        is_expected.to have_body_text(policy.name)
      end
    end
  end
end

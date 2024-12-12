# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuablePolicy, :models, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:non_member) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:planner) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let(:guest_issue) { create(:issue, project: project, author: guest) }
  let(:planner_issue) { create(:issue, project: project, author: planner) }
  let(:reporter_issue) { create(:issue, project: project, author: reporter) }
  let(:incident_issue) { create(:incident, project: project, author: developer) }

  before do
    project.add_guest(guest)
    project.add_planner(planner)
    project.add_reporter(reporter)
    project.add_developer(developer)
  end

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  describe '#rules' do
    shared_examples 'issuable resource links access' do
      it 'disallows non members' do
        expect(permissions(non_member, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(non_member, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows guests' do
        expect(permissions(guest, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(guest, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows planners' do
        expect(permissions(planner, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(planner, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows all on non-incident issue type' do
        expect(permissions(non_member, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(guest, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(developer, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(planner, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(reporter, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(non_member, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(guest, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(developer, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(planner, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(reporter, issue)).to be_disallowed(:read_issuable_resource_link)
      end
    end

    shared_examples 'measure comment temperature' do
      describe 'measure_comment_temperature' do
        let(:user) { developer }
        let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

        subject { permissions(user, issue) }

        where(:feature_flag_enabled, :user_allowed, :expected_result) do
          true  | true  | be_allowed(:measure_comment_temperature)
          true  | false | be_disallowed(:measure_comment_temperature)
          false | true  | be_disallowed(:measure_comment_temperature)
          false | false | be_disallowed(:measure_comment_temperature)
        end

        with_them do
          before do
            stub_feature_flags(comment_temperature: feature_flag_enabled)
            allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
            allow(authorizer).to receive(:allowed?).and_return(user_allowed)
          end

          it { is_expected.to expected_result }
        end
      end
    end

    context 'in a public project' do
      let_it_be(:project) { create(:project, :public) }
      let_it_be(:issue) { create(:issue, project: project) }

      it 'disallows non-members from creating and deleting metric images' do
        expect(permissions(non_member, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(non_member, issue)).to be_disallowed(:upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows guests to read, create metric images, and delete them in their own issues' do
        expect(permissions(guest, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(guest, issue)).to be_disallowed(:upload_issuable_metric_image, :destroy_issuable_metric_image)

        expect(permissions(guest, guest_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows planners to create and delete metric images' do
        expect(permissions(planner, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
        expect(permissions(planner, planner_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows reporters to create and delete metric images' do
        expect(permissions(reporter, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
        expect(permissions(reporter, reporter_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      context 'Create, read, delete issuable resource links' do
        context 'when available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(true)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'allows developers' do
            expect(permissions(developer, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end

          it 'allows reporters' do
            expect(permissions(reporter, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end
        end

        context 'when not available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(false)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'disallows developers' do
            expect(permissions(developer, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_disallowed(:read_issuable_resource_link)
          end

          it 'disallows reporters' do
            expect(permissions(reporter, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_disallowed(:read_issuable_resource_link)
          end
        end
      end
    end

    context 'in a private project' do
      let_it_be(:project) { create(:project, :private) }
      let_it_be(:issue) { create(:issue, project: project) }

      it 'disallows non-members from creating and deleting metric images' do
        expect(permissions(non_member, issue)).to be_disallowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows guests to read metric images, and create + delete in their own issues' do
        expect(permissions(guest, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(guest, issue)).to be_disallowed(:upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)

        expect(permissions(guest, guest_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows planners to create and delete metric images' do
        expect(permissions(planner, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
        expect(permissions(planner, planner_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      it 'allows reporters to create and delete metric images' do
        expect(permissions(reporter, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
        expect(permissions(reporter, reporter_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image)
      end

      context 'Create, read, delete issuable resource links' do
        context 'when available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(true)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'allows developers' do
            expect(permissions(developer, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end

          it 'allows reporters' do
            expect(permissions(reporter, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end
        end
      end
    end

    describe 'trigger_amazon_q' do
      let_it_be(:project) { create(:project, :private) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:user) { developer }
      let(:amazon_q_enabled) { true }

      before do
        allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
        allow(::Ai::AmazonQ).to receive(:enabled?).with(
          user: user,
          namespace: project.project_namespace
        ).and_return(amazon_q_enabled)
      end

      it 'allows on an issue authored by a guest' do
        expect(permissions(user, guest_issue)).to be_allowed(:trigger_amazon_q)
      end

      it 'allows on non-persisted issues' do
        issue = build(:issue, project: project)

        expect(permissions(user, issue)).to be_allowed(:trigger_amazon_q)
      end

      it 'allows on merge request' do
        expect(permissions(user, merge_request)).to be_allowed(:trigger_amazon_q)
      end

      it 'disallows non-member' do
        expect(permissions(non_member, merge_request)).to be_disallowed(:trigger_amazon_q)
      end

      it 'disallows work items without a project' do
        # note: We might want to do this in the future, but for now we're using the project_namespace for this check
        epic = build(:epic, group: project.group)

        expect(permissions(user, epic)).to be_disallowed(:trigger_amazon_q)
      end

      context 'when user is not developer+' do
        let(:user) { reporter }

        it 'disallows reporter' do
          expect(permissions(user, guest_issue)).to be_disallowed(:trigger_amazon_q)
        end
      end

      context 'when Amazon Q is disabled' do
        let(:amazon_q_enabled) { false }

        it 'disallows user' do
          expect(permissions(user, guest_issue)).to be_disallowed(:trigger_amazon_q)
        end
      end
    end
  end
end

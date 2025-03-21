# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::AccessibleOwnersFinder, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:maintainer_email) { create(:email, :confirmed, :skip_validate, user: maintainer).email }
  let_it_be(:non_member_email) { create(:email, :confirmed, :skip_validate, user: non_member).email }
  let_it_be(:external_group) { create(:group) }
  let_it_be(:invited_group) { create(:project_group_link, project: project).group }
  let_it_be(:project_group) { project.group }
  let_it_be(:parent_group) { project_group.parent }
  let_it_be(:invalid_names) { ['not_a_user', non_member.username, external_group.full_path] }
  let_it_be(:valid_usernames) { [guest.username, developer.username, maintainer.username] }
  let_it_be(:valid_group_names) { [invited_group.full_path, project_group.full_path, parent_group.full_path] }
  let_it_be(:input_names) { invalid_names + valid_usernames + valid_group_names }
  let_it_be(:invalid_emails) { ['not_a_user@mail.com', non_member.private_commit_email, non_member_email] }
  let_it_be(:valid_emails) { [guest.email, developer.email, maintainer.private_commit_email, maintainer_email] }
  let_it_be(:input_emails) { invalid_emails + valid_emails }
  let_it_be(:output_users) { [guest, developer, maintainer] }
  let_it_be(:output_groups) { [invited_group, project_group, parent_group] }

  subject(:finder) do
    described_class.new(project, names: input_names, emails: input_emails).tap(&:execute)
  end

  it 'finds all of the users who are project members assigns them to output_users' do
    expect(finder.output_users).to match_array(output_users)
  end

  it 'finds all groups which are invited or ancestors of the project and assigns them to output_groups' do
    expect(finder.output_groups).to match_array(output_groups)
  end

  it 'maps all of the invalid input_names to invalid_names' do
    expect(finder.invalid_names).to match_array(invalid_names)
  end

  it 'maps all of the valid input_names matching users to valid_usernames' do
    expect(finder.valid_usernames).to match_array(valid_usernames)
  end

  it 'maps all of the valid input_names matching groups to valid_group_names' do
    expect(finder.valid_group_names).to match_array(valid_group_names)
  end

  it 'maps all of the invalid input_names to invalid_names' do
    expect(finder.invalid_emails).to match_array(invalid_emails)
  end

  it 'maps all of the valid input_emails to valid_emails' do
    expect(finder.valid_emails).to match_array(valid_emails)
  end

  it 'does not perform N+1 queries', :request_store, :use_sql_query_cache do
    project_id = project.id
    project = Project.find(project_id)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      described_class.new(project, names: input_names, emails: input_emails).tap(&:execute)
    end

    create(:email, :confirmed, :skip_validate, user: create(:user))
    create(:email, :confirmed, :skip_validate, user: create(:user, guest_of: project))
    extra_developer = create(:user, developer_of: project)
    extra_developer_email = create(:email, :skip_validate, user: extra_developer).email
    create(:group)
    create(:project_group_link, project: project)
    extra_group = create(:project_group_link, project: project).group

    project = Project.find(project_id)
    names = input_names + ['foo', extra_developer.username, extra_group.full_path]
    emails = input_emails + ['foo@mail.com', extra_developer_email]

    expect do
      described_class.new(project, names: names, emails: emails).tap(&:execute)
    end.to issue_same_number_of_queries_as(control)
  end

  describe '#error_message' do
    subject(:error_message) { described_class.new(project).error_message }

    it { is_expected.to eq(:inaccessible_owner) }
  end
end

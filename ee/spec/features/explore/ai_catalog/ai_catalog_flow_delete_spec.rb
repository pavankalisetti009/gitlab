# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog Flow Delete', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:flow1) do
    create(:ai_catalog_flow, project_id: project.id, name: 'Flow 1', description: 'Flow Description', public: true)
  end

  before do
    enable_ai_catalog
  end

  describe 'Delete existing flow' do
    let!(:flow_to_delete) do
      create(:ai_catalog_flow, project_id: project.id, name: 'Flow to Delete',
        description: 'Will be deleted', public: true)
    end

    context 'when user is a maintainer' do
      before do
        sign_in(user)
        visit explore_ai_catalog_path
      end

      it('deletes flow via dropdown menu and confirms in modal') do
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(2)

        click_link(flow_to_delete.name)
        wait_for_requests
        expect(page).to have_content('Will be deleted')

        find_by_testid('more-actions-dropdown').click
        find_by_testid('delete-button').click

        expect(page).to have_content('Hide flow')
        expect(page).to have_content('Are you sure you want to hide flow Flow to Delete?')

        within('.gl-modal') do
          click_button 'Confirm'
        end

        wait_for_requests

        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        # Navigate back to Flows tab to verify deletion
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        # Verify the deleted flow is removed, but flow1 remains
        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
        expect(page).to have_content('Flow 1')
        expect(page).not_to have_content('Flow to Delete')
      end
    end

    context 'when user is an instance admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        sign_in(admin)
        enable_admin_mode!(admin)
        visit explore_ai_catalog_path
      end

      it('can soft delete (hide) flow from catalog') do
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        click_link(flow_to_delete.name)
        wait_for_requests

        find_by_testid('more-actions-dropdown').click
        find_by_testid('delete-button').click

        expect(page).to have_content('Delete flow')
        expect(page).to have_content('Deletion method')

        within('.gl-modal') do
          # Select soft delete option
          choose 'Hide from the AI Catalog'
          click_button 'Confirm'
        end

        wait_for_requests

        # Flow should be hidden from catalog but not permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        page.within('.gl-tabs') do
          click_link('Flows')
        end

        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
      end

      it('can hard delete (permanently delete) flow') do
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        click_link(flow_to_delete.name)
        wait_for_requests

        find_by_testid('more-actions-dropdown').click
        find_by_testid('delete-button').click

        expect(page).to have_content('Delete flow')

        within('.gl-modal') do
          # Select hard delete option (default)
          choose 'Delete permanently'
          click_button 'Confirm'
        end

        wait_for_requests

        # Flow should be permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        page.within('.gl-tabs') do
          click_link('Flows')
        end

        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
        expect(page).not_to have_content('Flow to Delete')
      end
    end

    context 'when user is a developer' do
      let_it_be(:developer) { create(:user) }

      before_all do
        project.add_developer(developer)
      end

      before do
        sign_in(developer)
        visit explore_ai_catalog_path
      end

      it('does not show delete button in dropdown') do
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        click_link(flow_to_delete.name)
        wait_for_requests

        find_by_testid('more-actions-dropdown').click
        expect(page).not_to have_css('[data-testid="delete-button"]')
      end
    end
  end
end

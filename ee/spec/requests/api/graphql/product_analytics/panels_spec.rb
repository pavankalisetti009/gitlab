# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe 'Query.project(id).dashboards.panels(id)', feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

  let(:query) do
    <<~GRAPHQL
      query {
        project(fullPath: "#{project.full_path}") {
          name
          customizableDashboards {
            nodes {
              title
              slug
              description
              errors
              panels {
                nodes {
                  title
                  tooltip {
                    description
                    descriptionLink
                  }
                  gridAttributes
                  visualization {
                    type
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    stub_licensed_features(product_analytics: true, project_merge_request_analytics: false)
  end

  context 'when current user is a developer' do
    let_it_be(:user) { create(:user, developer_of: project) }

    it 'returns panel' do
      get_graphql(query, current_user: user)

      expect(
        graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, 0)
      ).to match(
        hash_including(
          'title' => 'Overall Conversion Rate',
          'tooltip' => {
            'description' => 'Percentage of visitors who complete a desired action. %{linkStart}Learn more%{linkEnd}.',
            'descriptionLink' => 'https://gitlab.com'
          },
          'gridAttributes' => {
            'yPos' => 4,
            'xPos' => 1,
            'width' => 12,
            'height' => 2
          },
          'visualization' => hash_including(
            'type' => 'LineChart'
          )
        )
      )
    end

    context 'for panel tooltip' do
      let(:query) do
        <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              name
              customizableDashboards {
                nodes {
                  errors
                  panels {
                    nodes {
                      tooltip {
                        description
                        descriptionLink
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      context 'when tooltip has `description` but no `descriptionLink`' do
        it 'returns dashboard and panel tooltip without errors' do
          get_graphql(query, current_user: user)

          expect(
            graphql_data_at(:project,
              :customizable_dashboards, :nodes, 0, :errors)
          ).to be_nil

          expect(
            graphql_data_at(:project,
              :customizable_dashboards, :nodes, 0, :panels, :nodes, 1, :tooltip)
          ).to eq({
            'description' => 'Percentage of visitors who complete a desired action.',
            'descriptionLink' => nil
          })
        end
      end

      context 'when tooltip `description` is invalid' do
        let_it_be(:project) { create(:project, :with_product_analytics_dashboard_with_invalid_panel_tooltip) }
        let_it_be(:user) { create(:user, developer_of: project) }

        it 'returns dashboard with invalid panel tooltip error' do
          get_graphql(query, current_user: user)

          expect(
            graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :errors, 0)
          ).to eq("property '/panels/0/tooltip/description' does not match " \
            "pattern: .*%\\{linkStart\\}.*%\\{linkEnd\\}.*")
        end
      end
    end
  end
end

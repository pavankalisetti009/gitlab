# frozen_string_literal: true

module Groups
  module AddOns
    module DiscoverDuoProHelper
      def duo_pro_trial_status_track_action(namespace)
        if GitlabSubscriptions::DuoPro.active_trial_add_on_purchase_for_namespace?(namespace)
          'click_documentation_link_duo_pro_trial_active'
        else
          'click_documentation_link_duo_pro_trial_expired'
        end
      end

      def duo_pro_discover_card_collection(namespace)
        [
          {
            header: s_("DuoProDiscover|Accelerate your path to market"),
            body: s_(
              "DuoProDiscover|Develop and deploy secure software faster with AI in every phase " \
                "of the software development lifecycle — from planning and code creation to testing, " \
                "security, and monitoring."
            )
          },
          {
            header: s_("DuoProDiscover|Adopt AI with guardrails"),
            body: s_(
              "DuoProDiscover|With GitLab Duo, you control which users, projects, and groups can use " \
                "AI-powered capabilities. Also, your organization's proprietary code and data aren't used " \
                "to train AI models."
            )
          },
          {
            header: s_("DuoProDiscover|Improve developer experience"),
            body: s_(
              "DuoProDiscover|Give your developers a single platform that integrates the best AI model " \
                "for each use case across the entire workflow, from understanding code to fixing security " \
                "vulnerabilities."
            )
          },
          {
            header: s_("DuoProDiscover|Committed to transparent AI"),
            body: safe_format(
              s_(
                "DuoProDiscover|For organizations and teams to trust AI, it must be transparent. " \
                  "GitLab's %{link_start}AI Transparency Center%{link_end} details how we uphold ethics and " \
                  "transparency in our AI-powered features."
              ),
              tag_pair(
                link_to('', 'https://about.gitlab.com/ai-transparency-center/',
                  data: {
                    track_action: duo_pro_trial_status_track_action(namespace),
                    track_label: 'ai_transparency_center_feature'
                  },
                  class: 'gl-contents',
                  target: "_blank",
                  rel: "noopener noreferrer"),
                :link_start,
                :link_end
              )
            )
          }
        ]
      end
    end
  end
end

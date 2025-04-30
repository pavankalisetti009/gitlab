# frozen_string_literal: true

require "fast_spec_helper"
# NOTE This explicit "hashdiff" require exists so we can run this spec against historical SHAs, before the require
# existed in ee/spec/fast_spec_helper.rb. It can be removed once there is no longer a need to run it against
# historical SHAs.
require "hashdiff"

# noinspection RubyLiteralArrayInspection -- Keep original formatting for readability
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigGenerator, "Golden Master for desired_config", feature_category: :workspaces do
  # !!!! IMPORTANT NOTE !!!!
  # DO NOT ADD
  # include_context "with constant modules"
  # TO THIS FILE!!!
  # THIS FILE SHOULD HAVE ALL THE FIXTURE VALUES HARDCODED, IN ORDER TO PROVIDE PROPER REGRESSION COVERAGE
  # !!!!!!!!!!!!!!!!!!!!!!!!

  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version of these models, so we can use fast_spec_helper.
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:agent) { instance_double("Clusters::Agent", id: 991) }

  let(:workspace_variable_environment) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "ENV_VAR1",
      value: "env-var-value1"
    )
  end

  let(:workspace_variable_file) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "FILE_VAR1",
      value: "file-var-value1"
    )
  end

  # rubocop:disable RSpec/VerifiedDoubles -- This is a scope which is of type ActiveRecord::Associations::CollectionProxy, it can't be a verified double
  let(:workspace_variables) do
    double(
      :workspace_variables,
      with_variable_type_environment: [workspace_variable_environment],
      with_variable_type_file: [workspace_variable_file]
    )
  end
  # rubocop:enable RSpec/VerifiedDoubles

  let(:image_pull_secret_stringified) { { "name" => "registry-secret", "namespace" => "default" } }
  let(:image_pull_secret_symbolized) { { name: "registry-secret", namespace: "default" } }
  let(:image_pull_secret) { image_pull_secret_stringified }

  let(:workspaces_agent_config) do
    instance_double(
      "RemoteDevelopment::WorkspacesAgentConfig",
      allow_privilege_escalation: false,
      use_kubernetes_user_namespaces: false,
      default_runtime_class: "standard",
      default_resources_per_workspace_container:
        { requests: { cpu: "0.5", memory: "512Mi" }, limits: { cpu: "1", memory: "1Gi" } },
      # NOTE: This input version of max_resources_per_workspace is deeply UNSORTED, to verify the legacy behavior
      # that the "workspaces.gitlab.com/max-resources-per-workspace-sha256" annotation should be calculated
      # from the OpenSSL::Digest::SHA256.hexdigest of the #to_s of the SHALLOW sorted version of the hash. In other
      # words, the hash is calculated with limits and requests in alphabetical order, but not memory and cpu.
      max_resources_per_workspace: { requests: { memory: "1Gi", cpu: "1" }, limits: { memory: "4Gi", cpu: "2" } },
      annotations: { environment: "production", team: "engineering" },
      labels: { app: "workspace", tier: "development" },
      image_pull_secrets: [image_pull_secret],
      network_policy_enabled: true,
      network_policy_egress: [
        {
          allow: "0.0.0.0/0",
          except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
        }
      ],
      gitlab_workspaces_proxy_namespace: "gitlab-workspaces",
      dns_zone: "workspaces.localdev.me"
    )
  end

  let(:input_processed_devfile_yaml) { input_processed_devfile_yaml_with_poststart_event }

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      id: 993,
      agent: agent,
      workspaces_agent_config: workspaces_agent_config,
      name: "workspace-991-990-fedcba",
      namespace: "gl-rd-ns-991-990-fedcba",
      desired_state_running?: desired_state_running,
      desired_state_terminated?: desired_state_terminated,
      actual_state: 'Running',
      workspace_variables: workspace_variables,
      processed_devfile: input_processed_devfile_yaml
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  subject(:desired_config) do
    # noinspection RubyMismatchedArgumentType -- We are intentionally passing a double for Workspace
    described_class.generate_desired_config(
      workspace: workspace,
      include_all_resources: include_all_resources,
      logger: logger
    )
  end

  shared_examples "generated desired_config golden master checks" do
    it "exactly matches the generated desired_config", :unlimited_max_formatted_output_length do
      desired_config_sorted = desired_config.map(&:deep_symbolize_keys)

      golden_master_desired_config_sorted = golden_master_desired_config.map(&:deep_symbolize_keys)

      # compare the names and kinds of the resources
      expect(desired_config_sorted.map { |c| [c.fetch(:kind), c.fetch(:metadata).fetch(:name)] })
        .to eq(golden_master_desired_config_sorted.map { |c| [c.fetch(:kind), c.fetch(:metadata).fetch(:name)] })

      differences = {}

      # Use Hashdiff on each element to give a more concise and readable diff
      desired_config_sorted.each_with_index do |resource, index|
        # NOTE: The order of the diff is expected value first, actual value second. This matches the
        #       "expected ..., got ..." order which RSpec uses by default.
        resource_differences = Hashdiff.diff(golden_master_desired_config_sorted[index], resource)

        next unless resource_differences.present?

        key = "index=#{index}, kind='#{resource.fetch(:kind)}', name='#{resource.fetch(:metadata).fetch(:name)}'"
        value = resource_differences.map(&:inspect).join("\n").to_s
        differences[key] = value
      end

      expect(differences)
        .to be_empty, differences.map { |k, v| "Differences found in resource at #{k} \n#{v}" }.join("\n\n").to_s
    end
  end

  context "when desired_state is terminated" do
    let(:desired_state_running) { false }
    let(:desired_state_terminated) { true }
    let(:include_all_resources) { true }
    let(:golden_master_desired_config) { golden_master_desired_config_with_desired_state_terminated }

    it_behaves_like "generated desired_config golden master checks"
  end

  context "when include_all_resources is true" do
    let(:desired_state_running) { true }
    let(:desired_state_terminated) { false }
    let(:include_all_resources) { true }
    let(:golden_master_desired_config) { golden_master_desired_config_with_include_all_resources_true }

    it_behaves_like "generated desired_config golden master checks"

    context "with legacy devfile that does not include postStart event" do
      let(:input_processed_devfile_yaml) { input_processed_devfile_yaml_without_poststart_event }
      let(:golden_master_desired_config) do
        golden_master_desired_config_from_legacy_devfile_with_no_poststart_and_with_include_all_resources_true
      end

      it_behaves_like "generated desired_config golden master checks"
    end
  end

  context "when include_all_resources is false" do
    let(:desired_state_running) { true }
    let(:desired_state_terminated) { false }
    let(:include_all_resources) { false }
    let(:golden_master_desired_config) { golden_master_desired_config_with_include_all_resources_false }

    it_behaves_like "generated desired_config golden master checks"
  end

  # @return [String]
  def input_processed_devfile_yaml_with_poststart_event
    <<~YAML
      ---
      schemaVersion: 2.2.0
      metadata: {}
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
            args:
              - "echo 'tooling container args'"
            command:
              - "/bin/sh"
              - "-c"
            volumeMounts:
              - name: gl-workspace-data
                path: /projects
            env:
              - name: GL_ENV_NAME
                value: "gl-env-value"
            endpoints:
              - name: server
                targetPort: 60001
                exposure: public
                secure: true
                protocol: https
            dedicatedPod: false
            mountSources: true
        - name: gl-project-cloner
          container:
            image: alpine/git:2.45.2
            volumeMounts:
              - name: gl-workspace-data
                path: "/projects"
            args:
              - "echo 'project cloner container args'"
            command:
              - "/bin/sh"
              - "-c"
            memoryLimit: 1000Mi
            memoryRequest: 500Mi
            cpuLimit: 500m
            cpuRequest: 100m
        - name: gl-workspace-data
          volume:
            size: 50Gi
      commands:
        - id: gl-example-tooling-container-internal-command
          exec:
            commandLine: "echo 'example tooling container internal command'"
            component: tooling-container
        - id: gl-project-cloner-command
          apply:
            component: gl-project-cloner
      events:
        preStart:
          - gl-project-cloner-command
        postStart:
          - gl-example-tooling-container-internal-command
      variables: {}
    YAML
  end

  # @return [String]
  def input_processed_devfile_yaml_without_poststart_event
    <<~YAML
      ---
      schemaVersion: 2.2.0
      metadata: {}
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
            args:
              - "echo 'tooling container args'"
            command:
              - "/bin/sh"
              - "-c"
            volumeMounts:
              - name: gl-workspace-data
                path: /projects
            env:
              - name: GL_ENV_NAME
                value: "gl-env-value"
            endpoints:
              - name: server
                targetPort: 60001
                exposure: public
                secure: true
                protocol: https
            dedicatedPod: false
            mountSources: true
        - name: gl-project-cloner
          container:
            image: alpine/git:2.45.2
            volumeMounts:
              - name: gl-workspace-data
                path: "/projects"
            args:
              - "echo 'project cloner container args'"
            command:
              - "/bin/sh"
              - "-c"
            memoryLimit: 512Mi
            memoryRequest: 256Mi
            cpuLimit: 500m
            cpuRequest: 100m
        - name: gl-workspace-data
          volume:
            size: 50Gi
      commands:
        - id: gl-project-cloner-command
          apply:
            component: gl-project-cloner
      events:
        preStart:
          - gl-project-cloner-command
      variables: {}
    YAML
  end

  # @return [Array]
  # rubocop:disable Layout/LineLength, Style/WordArray -- Keep original formatting for readability
  # noinspection RubyLiteralArrayInspection
  def golden_master_desired_config_with_desired_state_terminated
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def golden_master_desired_config_with_include_all_resources_true
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
              },
              creationTimestamp: nil,
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'project cloner container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "alpine/git:2.45.2",
                    imagePullPolicy: "Always",
                    name: "gl-project-cloner-gl-project-cloner-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 508,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {
          ENV_VAR1: "ZW52LXZhci12YWx1ZTE="
        },
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {
          FILE_VAR1: "ZmlsZS12YXItdmFsdWUx",
          "gl_workspace_reconciled_actual_state.txt": "UnVubmluZw=="
        },
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def golden_master_desired_config_with_include_all_resources_false
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
              },
              creationTimestamp: nil,
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'project cloner container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "alpine/git:2.45.2",
                    imagePullPolicy: "Always",
                    name: "gl-project-cloner-gl-project-cloner-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 508,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      }
    ]
  end

  # @return [Array]
  def golden_master_desired_config_from_legacy_devfile_with_no_poststart_and_with_include_all_resources_true
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
              },
              creationTimestamp: nil,
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'project cloner container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "alpine/git:2.45.2",
                    imagePullPolicy: "Always",
                    name: "gl-project-cloner-gl-project-cloner-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "512Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "256Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 508,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          creationTimestamp: nil,
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {
          ENV_VAR1: "ZW52LXZhci12YWx1ZTE="
        },
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {
          FILE_VAR1: "ZmlsZS12YXItdmFsdWUx",
          "gl_workspace_reconciled_actual_state.txt": "UnVubmluZw=="
        },
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # rubocop:enable Layout/LineLength, Style/WordArray
end

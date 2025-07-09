local k = import 'k.libsonnet';
local retainSC = import 'local-path-retain.jsonnet';
{
  new(
    nodeName
  ):: {
    local this = self,
    configPVC: {
      apiVersion: k.std.apiVersion.core,
      kind: "PersistentVolumeClaim",
      metadata: {
        name: "komga-config-pvc",
      },
      spec: {
        accessModes: ["ReadWriteOnce"],
        resources: {
          requests: {
            storage: "1Gi",
          },
        },
        storageClassName: "local-path",
      },
    },

    dataPVC: {
      apiVersion: k.std.apiVersion.core,
      kind: "PersistentVolumeClaim",
      metadata: {
        name: "komga-data-pvc",
      },
      spec: {
        accessModes: ["ReadWriteOnce"],
        resources: {
          requests: {
            storage: "10Gi",
          },
        },
        storageClassName: retainSC.nameRef,
      },
    },

    deployment: {
      apiVersion: k.std.apiVersion.apps,
      kind: "Deployment",
      metadata: {
        name: "komga",
      },
      spec: {
        replicas: 1,
        selector: {
          matchLabels: {
            app: "komga",
          },
        },
        template: {
          metadata: {
            labels: {
              app: "komga",
            },
          },
          spec: {
            nodeSelector: {
              "kubernetes.io/hostname": nodeName,
            },
            containers: [{
              name: "komga",
              image: "gotson/komga:1.22.0@sha256:ba892ab3e082b17e73929b06b89f1806535bc72ef4bc6c89cd3e135af725afc3",
              env: [{
                name: "SERVER_SERVLET_CONTEXT_PATH",
                value: "/komga",
              }],
              ports: [{
                containerPort: 25600,
              }],
              volumeMounts: [
                { name: "config", mountPath: "/config" },
                { name: "data", mountPath: "/data" },
              ],
            }],
            volumes: [
              {
                name: "config",
                persistentVolumeClaim: {
                  claimName: this.configPVC.metadata.name,
                },
              },
              {
                name: "data",
                persistentVolumeClaim: {
                  claimName: this.dataPVC.metadata.name,
                },
              },
            ],
          },
        },
      },
    },

    service: {
      apiVersion: k.std.apiVersion.core,
      kind: "Service",
      metadata: {
        name: "komga",
      },
      spec: {
        selector: {
          app: "komga",
        },
        ports: [{
          protocol: "TCP",
          port: 80,
          targetPort: 25600,
        }],
      },
    },

    ingress: {
      apiVersion: k.std.apiVersion.net,
      kind: "Ingress",
      metadata: {
        name: "komga",
        annotations: {
          "traefik.ingress.kubernetes.io/router.entrypoints": "web",
        },
      },
      spec: {
        rules: [{
          host: "hydrogen-sulfide.tail4c9a.ts.net",
          http: {
            paths: [{
              path: "/komga",
              pathType: "Prefix",
              backend: {
                service: {
                  name: "komga",
                  port: {
                    number: 80,
                  },
                },
              },
            }],
          },
        }],
      },
    },

    // Aggregate all components
    resources:: [
      self.configPVC,
      self.dataPV,
      self.dataPVC,
      self.deployment,
      self.service,
      self.ingress,
    ],
  },
}

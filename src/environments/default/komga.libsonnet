local k = import 'k.libsonnet';
{
  new(params):: {
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
        storageClassName: "my-local-path-retain",
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
              "kubernetes.io/hostname": params.nodeName,
            },
            containers: [{
              name: "komga",
              image: "gotson/komga",
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
                  claimName: "komga-config-pvc",
                },
              },
              {
                name: "data",
                persistentVolumeClaim: {
                  claimName: "komga-data-pvc",
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

local utils = import 'utils.jsonnet';
local retainSC = import 'local-path-retain.jsonnet';
{
  new(
    nodeName,
    name='komga',
  ):: {
    local this = self,
    configPVC: {
      apiVersion: "v1",
      kind: "PersistentVolumeClaim",
      metadata: {
        name: "%s-config-pvc" % name, // TODO: remove the "-pvc" suffix
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
      apiVersion: "v1",
      kind: "PersistentVolumeClaim",
      metadata: {
        name: "%s-data-pvc" % name, // TODO: remove the "-pvc" suffix
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
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: {
        name: name,
      },
      spec: {
        replicas: 1,
        selector: {
          matchLabels: {
            app: name,
          },
        },
        template: {
          metadata: {
            labels: {} + this.deployment.spec.selector.matchLabels,
          },
          spec: {
            tolerations: [
              {
                key: "ephemeral",
                operator: "Exists",
                effect: "NoSchedule",
              },
            ],
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
                {
                  name: utils.assertEqualAndReturn(this.deployment.spec.template.spec.volumes[0].name, "config"),
                  mountPath: "/config",
                },
                {
                  name: utils.assertEqualAndReturn(this.deployment.spec.template.spec.volumes[1].name, "data"),
                  mountPath: "/data"
                },
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
      apiVersion: "v1",
      kind: "Service",
      metadata: {
        name: name,
      },
      spec: {
        // Note: a Deployment's selector is in .spec.selector.matchLabels, but a Service's selector is in .spec.selector directly.
        selector: this.deployment.spec.selector.matchLabels,
        ports: [{
          protocol: "TCP",
          port: 80,
          targetPort: 25600,
        }],
      },
    },

    ingress: {
      apiVersion: "networking.k8s.io/v1",
      kind: "Ingress",
      metadata: {
        name: name,
        annotations: {
          "kubernetes.io/ingress.class": "traefik",
          "traefik.ingress.kubernetes.io/router.entrypoints": "web",
        },
      },
      spec: {
        rules: [
          {
            host: "hydrogen-sulfide.tail4c9a.ts.net",
            http: {
              paths: [{
                path: "/komga",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: this.service.metadata.name,
                    port:{
                      number: utils.assertEqualAndReturn(this.service.spec.ports[0].port, 80),
                    },
                  },
                },
              }],
            },
          },
          {
            host: "komga.sdts.local",
            http: this.ingress.spec.rules[0].http, // TODO: somehow validate index
          },
        ],
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

local k = import 'k.libsonnet';

{
  new(params):: {
    configPVC: {
      apiVersion: k.std.apiVersion.core,
      kind: "PersistentVolumeClaim",
      metadata: {
        name: "syncthing-config-pvc",
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
        name: "syncthing-tmp-data-pvc",
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

    deployment: {
      apiVersion: k.std.apiVersion.apps,
      kind: "Deployment",
      metadata: {
        name: "syncthing",
      },
      spec: {
        selector: {
          matchLabels: {
            app: "syncthing",
          },
        },
        template: {
          metadata: {
            labels: {
              app: "syncthing",
            },
          },
          spec: {
            nodeSelector: {
              "kubernetes.io/hostname": params.nodeName,
            },
            containers: [{
              name: "syncthing",
              image: "linuxserver/syncthing:latest",
              env: [
                {
                  name: "PUID",
                  value: "1000",
                },
                {
                  name: "PGID", 
                  value: "1000",
                },
                {
                  name: "TZ",
                  value: "UTC",
                },
              ],
              ports: [
                {
                  containerPort: 8384,
                  name: "web",
                },
                {
                  containerPort: 22000,
                  name: "sync",
                },
                {
                  containerPort: 21027,
                  name: "discovery",
                  protocol: "UDP",
                },
              ],
              volumeMounts: [
                { name: "config", mountPath: "/config" },
                { name: "data", mountPath: "/data" },
              ],
              securityContext: {
                runAsUser: 1000,
                runAsGroup: 1000,
              },
            }],
            volumes: [
              {
                name: "config",
                persistentVolumeClaim: {
                  claimName: "syncthing-config-pvc",
                },
              },
              {
                name: "data",
                persistentVolumeClaim: {
                  claimName: "syncthing-tmp-data-pvc",
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
        name: "syncthing",
      },
      spec: {
        selector: {
          app: "syncthing",
        },
        ports: [
          {
            protocol: "TCP",
            port: 8384,
            targetPort: 8384,
            name: "web",
          },
          {
            protocol: "TCP",
            port: 22000,
            targetPort: 22000,
            name: "sync",
          },
          {
            protocol: "UDP",
            port: 21027,
            targetPort: 21027,
            name: "discovery",
          },
        ],
      },
    },

    middleware: {
      apiVersion: "traefik.io/v1alpha1",
      kind: "Middleware",
      metadata: {
        name: "syncthing-strip",
      },
      spec: {
        stripPrefix: {
          prefixes: [
            "/syncthing",
          ],
        },
      },
    },

    ingress: {
      apiVersion: k.std.apiVersion.net,
      kind: "Ingress",
      metadata: {
        name: "syncthing",
        annotations: {
          "traefik.ingress.kubernetes.io/router.entrypoints": "web",
          "traefik.ingress.kubernetes.io/router.middlewares": "syncthing-strip@kubernetescrd"
        },
      },
      spec: {
        rules: [{
          host: "hydrogen-sulfide.tail4c9a.ts.net",
          http: {
            paths: [{
              path: "/syncthing",
              pathType: "Prefix",
              backend: {
                service: {
                  name: "syncthing",
                  port: {
                    number: 8384,
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
      self.dataPVC,
      self.deployment,
      self.service,
      self.middleware,
      self.ingress,
    ],
  },
} 
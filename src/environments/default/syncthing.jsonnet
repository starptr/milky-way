local k = import 'k.libsonnet';
{
  new(
    nodeName,
    extraVolumes=[],
    extraVolumeMounts=[],
    name='syncthing',
    image='linuxserver/syncthing:latest',
  ):: {
    local this = self,
    local containerPortNames = {
      gui: 'gui',
      syncTcp: 'sync-tcp',
      syncUdp: 'sync-udp',
      discoveryUdpBroadcast: 'disco',
    },
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
    deployment: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: name,
        labels: {
          app: name,
        },
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
            labels: {
              app: name,
            },
          },
          spec: {
            nodeSelector: {
              "kubernetes.io/hostname": nodeName,
            },
            containers: [
              {
                name: name,
                image: image,
                ports: [
                  { containerPort: 8384, name: containerPortNames.gui },
                  { containerPort: 22000, name: containerPortNames.syncTcp },
                  { containerPort: 22000, name: containerPortNames.syncUdp, protocol: 'UDP' },
                  { containerPort: 21027, name: containerPortNames.discoveryUdpBroadcast, protocol: 'UDP' },
                ],
                volumeMounts: [
                  {
                    name: 'config',
                    mountPath: '/config',
                  },
                ] + extraVolumeMounts,
                env: [
                  { name: 'PUID', value: '1000' },
                  { name: 'PGID', value: '1000' },
                  { name: 'TZ', value: 'UTC' },
                ],
              },
            ],
            volumes: [
              {
                name: 'config',
                persistentVolumeClaim: {
                  claimName: this.configPVC.metadata.name,
                },
              },
            ] + extraVolumes,
          },
        },
      },
    },

    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: name,
        labels: {
          app: name,
        }
      },
      spec: {
        selector: {
          app: name,
        },
        ports: [
          { port: 8384, targetPort: containerPortNames.gui, name: 'gui' },
          { port: 22000, targetPort: containerPortNames.syncTcp, name: 'sync-tcp' },
          { port: 22000, targetPort: containerPortNames.syncUdp, protocol: 'UDP', name: 'sync-udp' },
          { port: 21027, targetPort: containerPortNames.discoveryUdpBroadcast, protocol: 'UDP', name: 'disco' },
        ],
      },
    },

    ingressFromTraefikToNginx: {
      apiVersion: k.std.apiVersion.net,
      kind: "Ingress",
      metadata: {
        name: "traefik-to-nginx-" + name,
        namespace: "ingress-nginx",
        annotations: {
          "kubernetes.io/ingress.class": "traefik",
          "traefik.ingress.kubernetes.io/router.entrypoints": "web",
        },
      },
      spec: {
        rules: [{
          host: "hydrogen-sulfide.tail4c9a.ts.net",
          http: {
            paths: [
              {
                path: "/syncthing",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: "ingress-nginx-controller",
                    port: {
                      number: 80,
                    },
                  },
                },
              },
            ],
          },
        }],
      },
    },

    ingress: {
      apiVersion: k.std.apiVersion.net,
      kind: "Ingress",
      metadata: {
        name: name,
        annotations: {
          "kubernetes.io/ingress.class": "nginx",
          "nginx.ingress.kubernetes.io/use-regex": "true",
          "nginx.ingress.kubernetes.io/rewrite-target": "/$2",
          "nginx.ingress.kubernetes.io/proxy-read-timeout": "600",
          "nginx.ingress.kubernetes.io/proxy-send-timeout": "600",
          "nginx.ingress.kubernetes.io/configuration-snippet": |||
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          |||,
        },
      },
      spec: {
        ingressClassName: "nginx",
        rules: [{
          host: "hydrogen-sulfide.tail4c9a.ts.net",
          http: {
            paths: [
              {
                path: "/syncthing(/|$)(.*)",
                pathType: "ImplementationSpecific",
                backend: {
                  service: {
                    name: name,
                    port: {
                      number: 8384,
                    },
                  },
                },
              }
            ]
          }
        }]
      }
    },

    resources:: [
      this.configPVC,
      this.deployment,
      this.service,
      this.ingress,
    ],
  },
}

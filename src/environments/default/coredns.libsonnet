local k = import 'k.libsonnet';
local utils = import 'utils.jsonnet';
{
  new(
    nodeSelector={},
    name="split-coredns-for-tailscale",
    image="coredns/coredns:1.12.2@sha256:af8c8d35a5d184b386c4a6d1a012c8b218d40d1376474c7d071bb6c07201f47d",
  ):: {
    local this = self,
    configMap: {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        name: name,
      },
      data: {
        Corefile: |||
          .:53 {
            errors
            log
            health
            hosts {
              100.110.15.98 syncthing.sdts.local
            }
            cache 30
            reload
          }
        |||,
      },
    },
    daemonSet: {
      apiVersion: "apps/v1",
      kind: "DaemonSet",
      metadata: {
        name: name,
      },
      spec: {
        selector: {
          matchLabels: {
            app: name,
          },
        },
        template: {
          metadata: {
            # Needs to have, at minimum, all of the `matchLabels` labels for the DaemonSet to control the pods correctly.
            # Can have more labels too.
            labels: {} + this.daemonSet.spec.selector.matchLabels,
          },
          spec: {
            hostNetwork: true,
            nodeSelector: nodeSelector,
            containers: [{
              name: "coredns",
              image: image,
              args: ["-conf", "/etc/coredns/Corefile"],
              ports: [
                {
                  containerPort: 53,
                  hostPort: 53,
                  protocol: "UDP",
                },
                {
                  containerPort: 53,
                  hostPort: 53,
                  protocol: "TCP",
                },
              ],
              volumeMounts: [{
                name: utils.assertEqualAndReturn(this.daemonSet.spec.template.spec.volumes[0].name, "config-volume"),
                mountPath: "/etc/coredns",
              }],
            }],
            volumes: [{
              name: "config-volume",
              configMap: {
                name: this.configMap.metadata.name,
              },
            }],
          },
        },
      },
    },
  },
}
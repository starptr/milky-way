local k = import 'k.libsonnet';
local utils = import 'utils.jsonnet';
local magic = {
  corednsPort: 1053,
};
{
  new(
    nodeSelector={},
    name="split-coredns-for-tailscale",
    image="coredns/coredns:1.12.2@sha256:af8c8d35a5d184b386c4a6d1a012c8b218d40d1376474c7d071bb6c07201f47d",
  )::
    local port = magic.corednsPort;
    {
      local this = self,
      configMap: {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          name: name,
        },
        data: {
          Corefile: |||
            .:%d {
              errors
              log
              health
              hosts {
                100.110.15.98 syncthing.sdts.local
              }
              cache 30
              reload
            }
          ||| % port,
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
              initContainers: [{
                name: "check-iptable-redirects",
                image: "debian:bookworm",
                securityContext: {
                  privileged: true,
                },
                command: ["/bin/sh", "-c", |||
                  apt update && apt install -y iproute2 iptables util-linux
                  echo "Checking for iptable redirects for Tailscale split DNS..."

                  TAILSCALE_IP=$(ip -4 addr show dev tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

                  if [ -z "$TAILSCALE_IP" ]; then
                    echo "Could not get Tailscale IP address. Failing initContainer."
                    exit 1
                  fi
                  echo "Found Tailscale IP: $TAILSCALE_IP"

                  nsenter --net=/proc/1/ns/net iptables --table nat --check PREROUTING --protocol udp --destination $TAILSCALE_IP --dport 53 --jump REDIRECT --to-port %(corednsPort)d || {
                    echo "Missing UDP redirect. Failing initContainer."
                    exit 1
                  }
                  echo "Found UDP redirect. Continuing..."

                  nsenter --net=/proc/1/ns/net iptables --table nat --check PREROUTING --protocol tcp --destination $TAILSCALE_IP --dport 53 --jump REDIRECT --to-port %(corednsPort)d || {
                    echo "Missing TCP redirect. Failing initContainer."
                    exit 1
                  }
                  echo "Found TCP redirect. Continuing..."

                  echo "All redirects found. Exiting initContainer successfully."
                  exit 0
                ||| % magic],
                // No need to mount the host's network namespace, since hostNetwork: true is already set
              }],
              containers: [{
                name: "coredns",
                image: image,
                args: ["-conf", "/etc/coredns/Corefile", "-dns.port", "%d" % port],
                ports: [
                  {
                    containerPort: port,
                    hostPort: port,
                    protocol: "UDP",
                  },
                  {
                    containerPort: port,
                    hostPort: port,
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
      resources:: [
        self.configMap,
        self.daemonSet,
      ],
    },
}
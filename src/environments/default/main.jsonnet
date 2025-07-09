local k = import 'k.libsonnet';
local komgaLib = import 'komga.libsonnet';
local syncthingLib = import 'syncthing.jsonnet';
local retainSC = import 'local-path-retain.jsonnet';

local komga = komgaLib.new(
  nodeName = 'hydrogen-sulfide',  // Set this to the node where the media is
);

{
  myLocalPathRetainSC: retainSC.storageClass,
  komga: komga,
  syncthing: syncthingLib.new(
    nodeName = 'hydrogen-sulfide',
    extraVolumeMounts = [
      {
        name: 'komga-data',
        mountPath: '/data/komga',
      },
    ],
    extraVolumes = [
      {
        name: 'komga-data',
        persistentVolumeClaim: {
          claimName: komga.dataPVC.metadata.name,
        },
      },
    ],
  ),
}

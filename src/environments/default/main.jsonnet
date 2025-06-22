local k = import 'k.libsonnet';
local komga = import 'komga.libsonnet';
local retainSC = import 'local-path-retain.jsonnet';

{
  myLocalPathRetainSC: retainSC.storageClass,
  komga: komga.new({
    nodeName: 'hydrogen-sulfide',  // Set this to the node where the media is
  }),
}

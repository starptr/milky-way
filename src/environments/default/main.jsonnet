local k = import 'k.libsonnet';
local komgaLib = import 'komga.libsonnet';
local retainSC = import 'local-path-retain.jsonnet';

local komga = komgaLib.new(
  nodeName = 'hydrogen-sulfide',  // Set this to the node where the media is
);

{
  myLocalPathRetainSC: retainSC.storageClass,
  komga: komga,
}

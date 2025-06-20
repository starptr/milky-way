local k = import 'k.libsonnet';
local komga = import 'komga.libsonnet';

k.std +
{
  components: {
    komga: komga.new({
      nodeName: "hydrogen-sulfide", // Set this to the node where the media is
    }),
  },
}

# Load-balancer integration

This AWS deployment uses AWS cloud-controller-manager (CCM), not MetalLB.
The assignment layout permits either implementation in this directory.

`values.yaml` contains CCM scheduling and cloud-provider settings.
`../install-addons.sh` supplies the cluster name and image version, then patches
host networking because the pinned chart does not expose it.

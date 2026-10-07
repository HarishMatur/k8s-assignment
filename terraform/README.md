# Cluster environment

This directory configures one self-managed Kubernetes environment using local
`modules/networking`, `modules/compute`, and `modules/kubernetes`. The consumer
selects environment values and renders the bootstrap templates.

## Files

- `main.tf`: module inputs, grouped by purpose.
- `locals.tf`: bootstrap rendering and the reserved control-plane address.
- `data.tf`: Canonical Ubuntu AMI lookup.
- `provider.tf`: Terraform/provider constraints, AWS region, and default tags.
- `variables.tf` and `outputs.tf`: environment interface.
- `backend.tf`: S3 backend declaration and settings.
- `modules/kubernetes/templates/`: control-plane and worker bootstrap scripts.

## Change process

1. Update environment inputs in your untracked `terraform.tfvars`.
2. Run `terraform fmt -check -recursive` and `terraform validate`.
3. Run `terraform plan -out=tfplan` and review additions, updates, and replacements.
4. Apply the reviewed plan with `terraform apply tfplan`.

Commit the provider lock file. Never commit state, plan files, private keys, or
kubeconfig. Do not run apply concurrently with another operator.

Cloud-init changes replace EC2 nodes because `user_data_replace_on_change` is
enabled. Review replacement plans carefully. A single control plane means downtime
during replacement. Changing subnet/AZ ordering also changes index-based placement.

For a repeatable production rollout, provide an explicit `ami_id`; the default AMI
lookup can select a newer image over time. All modules are included in this
repository, so a separate module checkout is not needed.

See the project README for add-ons, access, recovery, verification, and teardown.

## Deployment settings

The root README includes sample inputs; `variables.tf` lists the available
settings. Kubernetes minor selection and exact Debian package
pinning are separate: `kubernetes_version` selects the repository, while
`kubernetes_package_version` pins kubelet, kubeadm, and kubectl together. Set the
package pin to null only when intentionally accepting the latest patch.

Choose the Kubernetes package pin, kubeadm configuration API, Calico release, and
AWS CCM image together. Changing a version variable does not constitute a safe
in-place Kubernetes upgrade or guarantee arbitrary version combinations work.
The checked-in defaults reproduce the assignment's tested Kubernetes 1.31 stack;
they are not a recommendation of the newest production release.

Add-on scripts read `addon_versions` and `pod_cidr` directly from this Terraform
configuration. Environment overrides remain available for troubleshooting, but
record final selections in tfvars. Access and recovery also read the API port and
join-token lifetime from Terraform. Keep bootstrap string settings trusted: they
are rendered into privileged shell scripts.

The module exposes root-volume type, IOPS, throughput, KMS key, size, and API port.
Encryption and IMDSv2 remain mandatory. Ubuntu amd64 bootstrap, a single control
plane, and public networking remain architectural constraints, not arbitrary
toggles. Terraform and provider version constraints remain in `provider.tf`:
Terraform does not allow input variables in those constraints or module source.

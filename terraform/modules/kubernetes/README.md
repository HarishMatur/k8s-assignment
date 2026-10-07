# Kubernetes

Contains the kubeadm bootstrap templates and optional SSH provisioners. The consumer renders the templates for either cloud-init or remote-exec; this module runs the remote-exec path when selected. Workers bootstrap after the control plane publishes its join command.

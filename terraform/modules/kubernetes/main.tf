resource "terraform_data" "control_plane_bootstrap" {
  count            = var.bootstrap_method == "remote-exec" ? 1 : 0
  triggers_replace = [var.control_plane_instance_id]

  connection {
    type        = "ssh"
    host        = var.control_plane_public_ip
    user        = "ubuntu"
    private_key = sensitive(file(pathexpand(var.provisioner_private_key_path)))
    timeout     = "10m"
  }
  provisioner "file" {
    content     = var.control_plane_user_data
    destination = "/tmp/cluster-bootstrap.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo install -m 700 /tmp/cluster-bootstrap.sh /root/cluster-bootstrap.sh && rm /tmp/cluster-bootstrap.sh",
      "sudo bash -c 'if [ -s /etc/kubernetes/admin.conf ]; then echo Already-initialized; elif [ -e /etc/kubernetes/manifests/kube-apiserver.yaml ]; then echo Partial-initialization >&2; exit 1; else /root/cluster-bootstrap.sh >>/var/log/cluster-bootstrap.log 2>&1; fi'",
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get --raw=/readyz",
    ]
  }
}

resource "terraform_data" "worker_bootstrap" {
  count            = var.bootstrap_method == "remote-exec" ? var.worker_count : 0
  triggers_replace = [var.worker_instance_ids[count.index], var.control_plane_instance_id]

  connection {
    type        = "ssh"
    host        = var.worker_public_ips[count.index]
    user        = "ubuntu"
    private_key = sensitive(file(pathexpand(var.provisioner_private_key_path)))
    timeout     = "10m"
  }
  provisioner "file" {
    content     = var.worker_user_data
    destination = "/tmp/cluster-bootstrap.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo install -m 700 /tmp/cluster-bootstrap.sh /root/cluster-bootstrap.sh && rm /tmp/cluster-bootstrap.sh",
      "sudo bash -c 'if [ -s /etc/kubernetes/kubelet.conf ]; then echo Already-configured; else /root/cluster-bootstrap.sh >>/var/log/cluster-bootstrap.log 2>&1; fi'",
      "sudo systemctl is-active kubelet",
    ]
  }
  depends_on = [terraform_data.control_plane_bootstrap]
}

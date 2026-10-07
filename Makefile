SHELL := /usr/bin/env bash
KUBECONFIG ?= $(CURDIR)/terraform/kubeconfig
export KUBECONFIG

.PHONY: init validate plan apply kubeconfig connect recover preview addons deploy verify destroy
connect:
	bash scripts/connect.sh
recover:
	bash scripts/recover.sh
preview:
	kubectl -n web port-forward --address=127.0.0.1 svc/assignment-web-webserver 8080:80
init:
	terraform -chdir=terraform init
validate:
	terraform -chdir=terraform fmt -check -recursive
	terraform -chdir=terraform validate
	helm lint helm/webserver
plan:
	terraform -chdir=terraform plan -out=tfplan
apply:
	terraform -chdir=terraform apply tfplan
kubeconfig:
	@cd terraform && eval "$$(terraform output -raw get_kubeconfig_command)"
addons:
	bash addons/install-addons.sh
deploy:
	helm upgrade --install assignment-web helm/webserver --namespace web --create-namespace --wait
verify:
	kubectl get nodes,pods -A
	kubectl get pvc,svc -n web
destroy:
	-helm uninstall assignment-web -n web
	@echo "Wait for the AWS load balancer and EBS volume to be deleted before running: terraform -chdir=terraform destroy"

# подключаю переменные среды от композера
include ./docker/.env
export $(shell sed 's/=.*//' ./docker/.env)

# проверка наличия переменной с именем пользователя
ifeq ($(USER_NAME),)
  $(error USER_NAME is not set)
endif

# сборка образов, всех сразу или отдельно
.PHONY: build build_src build_ui build_engine
build: build_src
build_src: build_ui build_engine 
build_ui:
	cd src/ui ;\
	docker build -t $(USER_NAME)/crawler-ui .
build_engine:
	cd src/engine ;\
	docker build -t $(USER_NAME)/crawler-engine .


# заливка образов в репозиторий, требуется предварителньо залогиниться
.PHONY: check_login push push_ui push_engine
push: check_login push push_ui push_engine
check_login:
	if grep -q 'auths": {}' ~/.docker/config.json ; then echo "Please login to Docker HUb first" && exit 1; fi
push_ui: check_login
	docker push $(USER_NAME)/crawler-ui
push_engine: check_login
	docker push $(USER_NAME)/crawler-engine

# запуск и остановка
.PHONY: up down stop restart
up:
	cd docker && docker-compose up -d
down:
	cd docker && docker-compose down
stop:
	cd docker && docker-compose stop
stop_engine:
	cd docker && docker-compose stop engine
log:
	cd docker && docker-compose logs --follow
restart:  down up
reload: stop up


# инфраструктура
.PHONY: machine firewall
machine:
	docker-machine create \
	--driver google \
	--google-project $(GOOGLE_PROJECT_ID) \
	--google-disk-size 40 \
	--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
	--google-machine-type n1-standard-1 \
	--google-zone europe-west4-b \
	--google-scopes=\
	https://www.googleapis.com/auth/devstorage.read_only,\
	https://www.googleapis.com/auth/monitoring,\
	https://www.googleapis.com/auth/logging.write,\
	https://www.googleapis.com/auth/monitoring.write,\
	https://www.googleapis.com/auth/pubsub,\
	https://www.googleapis.com/auth/service.management.readonly,\
	https://www.googleapis.com/auth/servicecontrol,\
	https://www.googleapis.com/auth/trace.append \
	--engine-opt experimental=true \
	--engine-opt metrics-addr=0.0.0.0:9323 \
	docker-host
	docker-machine ssh docker-host gcloud auth list
	docker-machine ip docker-host
static_ip:
	gcloud compute instances delete-access-config docker-host --access-config-name "external-nat" 
	gcloud compute instances add-access-config docker-host --access-config-name "external-nat" --address $(GOOGLE_STATIC_IP)
	docker-machine regenerate-certs docker-host

.PHONY: firewall_ui
firewall: firewall_ui
# правило для приложения
firewall_ui:
	gcloud compute firewall-rules create crawler-ui-default --allow tcp:8000

.PHONY: test_env clean clean_all alert
test_env:
	env | sort

# очистка системы
clean:
	docker system prune --all

clean_all:
	docker system prune --all --volumes

# проверка алерта в слак
alert:
	curl -X engine -H 'Content-type: application/json' \
	--data '{"text":"Checking send alert to slack.\n Username: $(USER_NAME)  Channel: $(SLACK_CHANNEL)"}' \
 	$(SLACK_API_URL)

# Kubernetes
k8s_utils:
	cd ansible && ansible-playbook -i inventory.yml --ask-become-pass k8sutil.yml

k8s_terraform:
	cd kubernetes/terraform && terraform apply
k8s_terraform_destroy:
	cd kubernetes/terraform && terraform destroy
k8s_helm_init:
	kubectl apply -f kubernetes/tiller/tiller.yml
	helm init --service-account tiller
	kubectl get pods -n kube-system --selector app=helm
k8s_helm_gitlab:
	helm install --name gitlab --namespace dev   kubernetes/charts/gitlab -f kubernetes/charts/gitlab/values.yaml

k8s_nginx_ingress:
	helm install stable/nginx-ingress --name nginx

k8s_traefik_ingress:
	helm install stable/traefik --name traefik --namespace kube-system

k8s_prometheus:
	cd kubernetes/charts/prometheus && helm upgrade prom . -f custom_values.yaml -f alertmanager_config.yaml --install

k8s_crawler:
	cd kubernetes/charts/crawler && helm upgrade crawler-test . --install
	cd kubernetes/charts/crawler && helm upgrade production --namespace production . --install
	cd kubernetes/charts/crawler && helm upgrade staging --namespace staging . --install

k8s_grafana_provisioning:
	kubectl create configmap grafana-prometheus-datasource  --from-file=prometheus.yaml=kubernetes/grafana/datasources/prometheus.yaml
	kubectl label configmap grafana-prometheus-datasource grafana_datasource=1
	kubectl create configmap grafana-k8s-dashboard  --from-file=k8s-dashboard.json=kubernetes/grafana/dashboards/k8s.json
	kubectl label configmap grafana-k8s-dashboard grafana_dashboard=1
	kubectl create configmap grafana-k8s-deployment-dashboard  --from-file=k8s-deployment-dashboard.json=kubernetes/grafana/dashboards/k8s-deployment.json
	kubectl label configmap grafana-k8s-deployment-dashboard grafana_dashboard=1

k8s_grafana:
	helm upgrade --install grafana stable/grafana  \
	--set "service.type=NodePort" \
	--set "ingress.enabled=true" \
	--set "ingress.hosts={crawler-grafana}" \
	--set "sidecar.dashboards.enabled=true" \
	--set "sidecar.dashboards.label=grafana_dashboard" \
	--set "sidecar.datasources.enabled=true" \
	--set "sidecar.datasources.label=grafana_datasource"
	kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

k8s_efk:
	cd kubernetes/charts/efk && helm dep update && helm upgrade efk . --install

k8s_kibana:
	helm upgrade --install kibana stable/kibana \
	--set "ingress.enabled=true" \
	--set "ingress.hosts={crawler-kibana}" \
	--set "env.ELASTICSEARCH_URL=http://elasticsearch-logging:9200" \
	--version 0.1.1

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
	cd src/crawler ;\
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
stop_post:
	cd docker && docker-compose stop post
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

# проверка алерат в слак
alert:
	curl -X POST -H 'Content-type: application/json' \
	--data '{"text":"Checking send alert to slack.\n Username: $(USER_NAME)  Channel: $(SLACK_CHANNEL)"}' \
 	$(SLACK_API_URL)

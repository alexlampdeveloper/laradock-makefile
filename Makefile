LARADOCK=laradock

# container names
PHP_CONTAINER_NAME=$(LARADOCK)_php-fpm_1
DB_CONTAINER_NAME=$(LARADOCK)_mysql_1
WORKSPACE_CONTAINER_NAME=$(LARADOCK)_workspace_1
REDIS_CONTAINER_NAME=$(LARADOCK)_redis_1
HORIZON_CONTAINER_NAME=$(LARADOCK)_laravel-horizon_1
NODE_IMAGE_NAME=node

# mysql variables
DB_DATABASE=default
DB_USERNAME=default
DB_PASSWORD=secret

# date
DATE=$(shell date +'%Y-%m-%d')

LIST_OF_CONTAINERS_TO_RUN=nginx mysql redis laravel-horizon workspace


# some variables that required by installation target
LARADOCK_REPO=https://github.com/bazavlukd/laradock.git

# the first target is the one that executed by default
# when uesr call make with no target.
# let's do nothing in this case
.PHONY: nop
nop:
	@echo "Please pass a target you want to run"

# custom targets

# put them here

#--------

# clone the repo
# replace some variabls in laradock's .env file
# create and update .env file of laravel
# replace some env variables in laravel's .env file
.PHONY: install-laradock
install-laradock:
	git clone $(LARADOCK_REPO) $(LARADOCK) && \
	cp $(LARADOCK)/env-example $(LARADOCK)/.env && \
	sed -i'.bak' "s/DATA_PATH_HOST=.*/DATA_PATH_HOST=..\/docker-data/" $(LARADOCK)/.env && \
	sed -i'.bak' "s/PHP_FPM_INSTALL_YAML=.*/PHP_FPM_INSTALL_YAML=true/" $(LARADOCK)/.env && \
	sed -i'.bak' "s/WORKSPACE_INSTALL_PYTHON=.*/WORKSPACE_INSTALL_PYTHON=true/" $(LARADOCK)/.env && \
	sed -i'.bak' "s/COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=$(LARADOCK)/" $(LARADOCK)/.env && \
	rm $(LARADOCK)/.env.bak && \
	(test -s .env || cp .env.example .env) ; \
	sed -i'.bak' "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env && \
	sed -i'.bak' "s/DB_HOST=.*/DB_HOST=mysql/" .env && \
	sed -i'.bak' "s/DB_DATABASE=.*/DB_DATABASE=$(DB_DATABASE)/" .env && \
	sed -i'.bak' "s/DB_USERNAME=.*/DB_USERNAME=$(DB_USERNAME)/" .env && \
	sed -i'.bak' "s/DB_PASSWORD=.*/DB_PASSWORD=$(DB_PASSWORD)/" .env && \
	sed -i'.bak' "s/REDIS_HOST=.*/REDIS_HOST=redis/" .env && \
	rm .env.bak && \
	chmod -R 777 storage

# run initial scripts
# key generate
# fix mysql passwords
# run migrations/seeds
# install composer dependencies
# install js dependencies
.PHONY: initial-build
initial-build:
	docker exec -it $(WORKSPACE_CONTAINER_NAME) composer install
	docker exec -it $(DB_CONTAINER_NAME) mysql -u root -proot -e "ALTER USER '$(DB_USERNAME)' IDENTIFIED WITH mysql_native_password BY '$(DB_PASSWORD)';";
	docker exec -it $(PHP_CONTAINER_NAME) bash -c 'php artisan key:generate'
	docker exec -it $(PHP_CONTAINER_NAME) bash -c 'php artisan jwt:secret'
	docker exec -it $(PHP_CONTAINER_NAME) bash -c "php artisan migrate --seed"
	docker exec -it -w /var/www/$(FRONTEND) $(WORKSPACE_CONTAINER_NAME) yarn

# run all containers
.PHONY: up
up:
	cd $(LARADOCK) && docker-compose up -d $(LIST_OF_CONTAINERS_TO_RUN)

# stop all containers
.PHONY: down
down:
	cd $(LARADOCK) && docker-compose down

# show laravel's log in realtime
.PHONY: log
log:
	tail -f storage/logs/laravel-$(DATE).log

# show docker log
.PHONY: docker-log
docker-log:
	cd $(LARADOCK) && docker-compose logs -f

# JOIN containers targets

.PHONY: join-workspace
join-workspace:
	docker exec -it $(WORKSPACE_CONTAINER_NAME) bash

.PHONY: join-php
join-php:
	docker exec -it $(PHP_CONTAINER_NAME) bash

.PHONY: join-db
join-db:
	docker exec -it $(DB_CONTAINER_NAME) mysql -u default -p default
#------------------

# javascript related targets
.PHONY: build-js-production
build-js-production:
	docker exec -it -w /var/www/$(FRONTEND) $(WORKSPACE_CONTAINER_NAME) yarn build

.PHONY: js-install
js-install:-w /var/www/$(FRONTEND) 
	docker exec -it -w /var/www/$(FRONTEND) $(WORKSPACE_CONTAINER_NAME) yarn

.PHONY: fix-js
fix-js:
	docker exec -it -w /var/www/$(FRONTEND) $(WORKSPACE_CONTAINER_NAME) yarn lint --fix

.PHONY: watch-js
watch-js:
	docker exec -it -w /var/www/$(FRONTEND) $(WORKSPACE_CONTAINER_NAME) yarn serve
#------------------

# queue related targets
.PHONY: queue-flush
queue-flush:
	docker exec -it $(REDIS_CONTAINER_NAME) redis-cli flushall

.PHONY: horizon
horizon:
	docker exec -it $(WORKSPACE_CONTAINER_NAME) bash -c 'php artisan horizon'
#------------------

# some artisan helpers

.PHONY: key-genrate
key-generate:
	docker exec -it $(PHP_CONTAINER_NAME) bash -c 'php artisan key:generate'

.PHONY: new-migration
new-migration:
	@read -p "Migration name: " migrationname; \
	docker exec -it $(PHP_CONTAINER_NAME) bash -c "php artisan make:migration $$migrationname";

.PHONY: run-migrations
run-migrations:
	docker exec -it $(PHP_CONTAINER_NAME) bash -c "php artisan migrate"

.PHONY: run-seeds
run-seeds:
	docker exec -it $(PHP_CONTAINER_NAME) bash -c 'php artisan db:seed'

.PHONY: new
new:
	@read -p "Make command and name (e.g. event TestEvent): " commandname;\
	docker exec -it $(PHP_CONTAINER_NAME) bash -c "php artisan make:$$commandname";
#------------------

# run tests with phpunit
.PHONY: test
test:
	docker exec -it $(PHP_CONTAINER_NAME) ./vendor/bin/phpunit

# install composer dependencies
.PHONY: composer-install
composer-install:
	docker exec -it $(WORKSPACE_CONTAINER_NAME) composer install

# # Debezium 공식 튜토리얼 상 등장한 command 라인 모음
# https://debezium.io/documentation/reference/stable/tutorial.html

# # Docker 관련 옵션 설명

# ## docker run 옵션
# -it 			        : Container 에 터미널 std 인/아웃 풋이 붙는다.
# --rm 			        : Container 가 stop 할 때 Container 를 제거한다.
# -p 3333:4444		  : 도커 호스트의 포트와 컨테이너 포트를 매핑한다. <도커포트>:<컨테이너포트>
# --name <name>		  : 컨테이너의 이름
# --link <n1>:<n2> 	: n1 호스트를 n2 컨테이너 이름으로 매핑한다.
# -e <변수>=<값>	    : 환경변수 설정

# # 컨테이너 실행 명령

# ## 주키퍼 스타트
docker run -it --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 quay.io/debezium/zookeeper:3.0

# ## 카프카 스타트
docker run -it --rm --name kafka -p 9092:9092 --link zookeeper:zookeeper quay.io/debezium/kafka:3.0

# ## MySQL Sample 스타트
# mysql:8.2 이미지 베이스
docker run -it --rm --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=debezium -e MYSQL_USER=mysqluser -e MYSQL_PASSWORD=mysqlpw quay.io/debezium/example-mysql:3.0

# ## MySQL CLI 클라이언트 스타트
docker run -it --rm --name mysqlterm --link mysql mysql:8.2 sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'

# ## 카프카 커넥트 스타트
docker run -it --rm --name connect -p 8083:8083 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses --link kafka:kafka --link mysql:mysql quay.io/debezium/connect:3.0

# # 카프카 커넥트 MySQL 커넥터 배포
# ## `inventory` DB 모니터링 커넥터 등록
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{ "name": "inventory-connector", "config": { "connector.class": "io.debezium.connector.mysql.MySqlConnector", "tasks.max": "1", "database.hostname": "mysql", "database.port": "3306", "database.user": "debezium", "database.password": "dbz", "database.server.id": "184054", "topic.prefix": "dbserver1", "database.include.list": "inventory", "schema.history.internal.kafka.bootstrap.servers": "kafka:9092", "schema.history.internal.kafka.topic": "schemahistory.inventory" } }'

# ## inventory-connector 등록여부 확인
# 응답이 "["inventory-connector"]" 로 확인되어야 한다.
curl -H "Accept:application/json" localhost:8083/connectors/

# ## 커넥터의 태스크 확인
curl -i -X GET -H "Accept:application/json" localhost:8083/connectors/inventory-connector

# # Change 이벤트들 확인하기
# 예제 상 dbserver1.inventory.customers 토픽을 확인하여 `investory` DB 의 이벤트를 확인한다.
# -a	: 토픽 생성 이후 발생한 모든 이벤트를 본다. 이 옵션이 없다면, `watch-topic` 은 시작 시점을 기준으로 기록된 이벤트를 보인다.
# -k	: 아웃풋이 이벤트 키를 포함하도록 한다.
docker run -it --rm --name watcher --link zookeeper:zookeeper --link kafka:kafka quay.io/debezium/kafka:3.0 watch-topic -a -k dbserver1.inventory.customers

# # 카프카 커넥트 재실행
docker stop connect
docker run -it --rm --name connect -p 8083:8083 -e GROUP_ID=1 -e CONFIG_STORAGE_TOPIC=my_connect_configs -e OFFSET_STORAGE_TOPIC=my_connect_offsets -e STATUS_STORAGE_TOPIC=my_connect_statuses --link zookeeper:zookeeper --link kafka:kafka --link mysql:mysql quay.io/debezium/connect:3.0

# # Cleaning Up
docker stop mysqlterm watcher connect mysql kafka zookeeper


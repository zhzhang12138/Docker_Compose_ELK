# 前提
# 1、因为ElasticSearch是用Java语言编写的，所以必须安装JDK的环境，并且是JDK 1.8以上。
# 安装java
# sudo yum install java-11-openjdk -y
# 安装完成查看java版本
# java -version

# HOST
ES_HOST=ES_HOST
LOG_HOST=LOG_HOST
KB_HOST=KB_HOST

# 0 清理环境
rm -rf /elk/elasticsearch
rm -rf /elk/logstash
rm -rf /elk/kibana
rm -rf /elk/filebeat

# 1、ElasticSearch服务
mkdir -p /elk/elasticsearch/config/
mkdir -p /elk/elasticsearch/data/
mkdir -p /elk/elasticsearch/plugins/
chmod -R 777 /elk/elasticsearch
# 创建ElasticSearch配置文件
echo "http.host: 0.0.0.0">>/elk/elasticsearch/config/elasticsearch.yml


# 2、Logstash服务
mkdir -p /elk/logstash/config/conf.d
chmod -R 777 /elk/logstash
# 创建Logstash配置文件
cat <<EOF > /elk/logstash/config/conf.d/logstash.conf
input {
  # 来源beats
  beats {
      # 端口
      port => "5044"
  }
}

output {
  elasticsearch {
    hosts => ["http://${ES_HOST}:9200"]
    index => "test"
  }
  stdout { codec => rubydebug }
}
EOF


# 3、Kibana服务
mkdir -p /elk/kibana/config
chmod -R 777 /elk/kibana
# 创建kibana配置文件
cat <<EOF > /elk/kibana/config/kibana.yml 
# Default Kibana configuration for docker target
server.name: kibana
server.host: "0"
elasticsearch.hosts: [ "http://${ES_HOST}:9200" ]
xpack.monitoring.ui.container.elasticsearch.enabled: true
i18n.locale: "zh-CN"		# 设置为中文
EOF


# 4、Filebeat服务
mkdir -p /elk/filebeat/config
mkdir -p /elk/filebeat/logs
mkdir -p /elk/filebeat/data
chmod -R 777 /elk/filebeat
# 创建Filebeat配置文件
cat <<EOF > /elk/filebeat/config/filebeat.yml
# Default Filebeat Config
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      # 容器中目录下的所有.log文件
      - /usr/share/filebeat/logs/*.log
    multiline.pattern: ^\[
    multiline.negate: true
    multiline.match: after

filebeat.config.modules:
  # 此处需要用到转移符
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

setup.dashboards.enabled: false

setup.kibana:
  host: "http://${KB_HOST}:5601"

# 直接传输至ES
#output.elasticsearch:
# hosts: ["http://es-master:9200"]
# index: "filebeat-%{[beat.version]}-%{+yyyy.MM.dd}"

# 传输至LogStash
output.logstash:
  hosts: ["${LOG_HOST}:5044"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF


# 5、启动
docker-compose up -d







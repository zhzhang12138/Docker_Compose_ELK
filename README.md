### ELK Stack单节点

> 本分支使用ElasticSearch官方的镜像和Docker-Compose来创建单节点的ELK Stack；
>
> https://www.docker.elastic.co/#

在ELK Stack中同时包括了Elastic Search、LogStash、Kibana以及Filebeat；

各个组件的作用如下：

- Filebeat：采集文件等日志数据；
- LogStash：过滤日志数据；
- Elastic Search：存储、索引日志；
- Kibana：用户界面；

各个组件之间的关系如下图所示：

![image-20221117141758485](https://picture-typora-bucket.oss-cn-shanghai.aliyuncs.com/typora/image-20221117141758485.png)

### 一 、项目环境

因为ElasticSearch是用Java语言编写的，所以必须安装JDK的环境，并且是JDK 1.8以上。

```bash
# 安装
sudo yum install java-11-openjdk -y


# 安装完成查看java版本
java -version
>>>:
[root@VM-0-5-centos config]# java --version
openjdk 11.0.16.1 2022-08-12 LTS
OpenJDK Runtime Environment (Red_Hat-11.0.16.1.1-1.el7_9) (build 11.0.16.1+1-LTS)
OpenJDK 64-Bit Server VM (Red_Hat-11.0.16.1.1-1.el7_9) (build 11.0.16.1+1-LTS, mixed mode, sharing)
```

#### **各个环境版本**

- 操作系统：CentOS 7
- Docker：20.10.18
- Docker-Compose：2.4.1
- ELK Version：7.4.2
- Filebeat：7.4.2
- JAVA：11.0.16.1

#### Docker-Compose变量配置

> 首先，在配置文件`.env`中统一声明了ES以及各个组件的版本：

.env

```
ES_VERSION=7.1.0
```

#### Docker-Compose服务配置

> 创建Docker-Compose的配置文件：

```yaml
version: '3.4'

services:
    elasticsearch:
        image: "docker.elastic.co/elasticsearch/elasticsearch:${ES_VERSION}"
        environment:
            - discovery.type=single-node
        volumes:
            - /etc/localtime:/etc/localtime
            - /elk/elasticsearch/data:/usr/share/elasticsearch/data
            - /elk/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
            - /elk/elasticsearch/plugins:/usr/share/elasticsearch/plugins
        ports:
            - "9200:9200"
            - "9300:9300"
    
    logstash:
        depends_on:
            - elasticsearch
        image: "docker.elastic.co/logstash/logstash:${ES_VERSION}"
        volumes:
            - /elk/logstash/config/conf.d/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
        ports:
            - "5044:5044"
        links:
            - elasticsearch

    kibana:
        depends_on:
            - elasticsearch
        image: "docker.elastic.co/kibana/kibana:${ES_VERSION}"
        volumes:
            - /etc/localtime:/etc/localtime
            # kibana.yml配置文件放在宿主机目录下,方便后续汉化
            - /elk/kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml
        ports:
            - "5601:5601"
        links:
            - elasticsearch

    filebeat:
        depends_on:
            - elasticsearch
            - logstash
        image: "docker.elastic.co/beats/filebeat:${ES_VERSION}"
        user: root # 必须为root
        environment:
            - strict.perms=false
        volumes:
            - /elk/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
            # 映射到容器中[作为数据源]
            - /elk/filebeat/logs:/usr/share/filebeat/logs:rw
            - /elk/filebeat/data:/usr/share/filebeat/data:rw
        # 将指定容器连接到当前连接，可以设置别名，避免ip方式导致的容器重启动态改变的无法连接情况
        links:
            - logstash

```

### 二、在Services中声明了四个服务

- elasticsearch
- logstash
- kibana
- filebeat

#### ElasticSearch服务

> 创建docker容器挂在的目录

**注意：chmod -R 777 /elk/elasticsearch 要有访问权限**

```bash
mkdir -p /elk/elasticsearch/config/
mkdir -p /elk/elasticsearch/data/
mkdir -p /elk/elasticsearch/plugins/
echo "http.host: 0.0.0.0">>/elk/elasticsearch/config/elasticsearch.yml
```

> 在elasticsearch服务的配置中有几点需要特别注意：

- `discovery.type=single-node`：将ES的集群发现模式配置为单节点模式；
- `/etc/localtime:/etc/localtime`：Docker容器中时间和宿主机同步；
- `/docker_es/data:/usr/share/elasticsearch/data`：将ES的数据映射并持久化至宿主机中；
- `/elk/elasticsearch/plugins:/usr/share/elasticsearch/plugins`：将插件挂载到主机；
- `/elk/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml`：将配置文件挂载到主机；

#### Logstash服务

> 创建docker容器挂在的目录

**注意：chmod -R 777 /elk/logstash 要有访问权限**

```bash
mkdir -p /elk/logstash/config/conf.d
```

> 在logstash服务的配置中有几点需要特别注意：

- `/elk/logstash/config/conf.d/logstash.conf:/usr/share/logstash/pipeline/logstash.conf`：将宿主机本地的logstash配置映射至logstash容器内部；

下面是LogStash的配置，在使用时可以自定义logstash.conf：

```javascript
input {
  # 来源beats
  beats {
      # 端口
      port => "5044"
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "test"
  }
  stdout { codec => rubydebug }
}
```

在这里我们将原来tcp收集方式修改为由filebeat上报，同时固定了索引为`test`；

#### **Kibana服务**

> 创建docker容器挂在的目录

**注意：chmod -R 777 /elk/kibana 要有访问权限**

```bash
mkdir -p /elk/kibana/config
```

在kibana服务的配置中有几点需要特别注意：

- `/elk/kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml`：配置ES的地址；
- `/etc/localtime:/etc/localtime`：Docker容器中时间和宿主机同步；

**修改 kibana.yml 配置文件，新增(修改)配置项`i18n.locale: "zh-CN"`**

```bash
[root@VM-0-5-centos ~]# cd /mydata/kibana/config

[root@VM-0-5-centos config]# cat kibana.yml 
# Default Kibana configuration for docker target
server.name: kibana
server.host: "0"
elasticsearch.hosts: [ "http://elasticsearch:9200" ]
xpack.monitoring.ui.container.elasticsearch.enabled: true
i18n.locale: "zh-CN"		# 设置为中文

[root@VM-0-5-centos config]# 
```

#### **Filebeat服务**

**注意：chmod -R 777 /elk/filebeat 要有访问权限**

> 创建docker容器挂在的目录

```bash
mkdir -p /elk/filebeat/config
mkdir -p /elk/filebeat/logs
mkdir -p /elk/filebeat/data
```

> 在Filebeat服务的配置中有几点需要特别注意

- 配置`user: root`和环境变量`strict.perms=false`：如果不配置可能会因为权限问题无法启动；

```shell
volumes:
-  - /elk/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
+	 - <your_log_path>/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
-  - /elk/filebeat/logs:/usr/share/filebeat/logs:rw
+	 - <your_log_path>:/usr/share/filebeat/logs:rw
-  - /elk/filebeat/data:/usr/share/filebeat/data:rw
+	 - <your_data_path>:/usr/share/filebeat/logs:rw
```

> 同时还需要创建Filebeat配置文件：

filebeat.yml

```yaml
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
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

setup.dashboards.enabled: false

setup.kibana:
  host: "http://kibana:5601"

# 直接传输至ES
#output.elasticsearch:
# hosts: ["http://es-master:9200"]
# index: "filebeat-%{[beat.version]}-%{+yyyy.MM.dd}"

# 传输至LogStash
output.logstash:
  hosts: ["logstash:5044"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
```

上面给出了一个filebeat配置文件示例，实际使用时可以根据需求进行修改；

### 三、使用方法

#### 方法一

> **使用前必看：**
>
> **① 修改ELK版本**
>
> 可以修改在`.env`中的`ES_VERSION`字段，修改你想要使用的ELK版本；
>
> **② LogStash配置**
>
> 修改`logstash.conf`为你需要的日志配置；
>
> **③ 修改ES文件映射路径**
>
> 修改`docker-compose`中`elasticsearch`服务的`volumes`，将宿主机路径修改为你实际的路径：
>
> ```diff
> volumes:
>   - /etc/localtime:/etc/localtime
> -  - /docker_es/data:/usr/share/elasticsearch/data
> + - [your_path]:/usr/share/elasticsearch/data
> ```
>
> 并且修改宿主机文件所属：
>
> ```bash
> sudo chown -R 1000:1000 [your_path]
> ```
>
> **④ 修改filebeat服务配置**
>
> 修改`docker-compose`中`filebeat`服务的`volumes`，将宿主机路径修改为你实际的路径：
>
> ```diff
> volumes:
>     - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
> -    - /elk/filebeat/logs:/usr/share/filebeat/logs:rw
> +	 - <your_log_path>:/usr/share/filebeat/logs:rw
> -    - /elk/filebeat/data:/usr/share/filebeat/data:rw
> +	 - <your_data_path>:/usr/share/filebeat/logs:rw
> ```
>
> **⑤ 修改Filebeat配置**
>
> 修改`filebeat.yml`为你需要的配置；
>
> Filebeat配置文件详情参见：https://www.jianshu.com/p/1ec30324a939

#### 方法二

```bash
1、拉取代码到本地
2、cd ELK
3、修改run.sh里面的ES_HOST、LOG_HOST、KB_HOST
3、chmod +x ./run.sh  #使脚本具有执行权限
4、./run.sh  #执行脚本
```

### 四、启动

随后使用docker-compose命令启动：

```bash
docker-compose up -d
Creating network "docker_repo_default" with the default driver
Creating docker_repo_elasticsearch_1 ... done
Creating docker_repo_kibana_1        ... done
Creating docker_repo_logstash_1      ... done
Creating docker_repo_filebeat_1      ... done
```


参考网站：
    https://github.com/JasonkayZK/docker-repo/tree/elk-stack-v7.1-single#docker-compose%E5%8F%98%E9%87%8F%E9%85%8D%E7%BD%AE

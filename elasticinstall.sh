echo "----------------------------------"
echo "CONFIGURING ELASTICSEARCH"
echo "----------------------------------"
cd /srv/
mkdir salt && cd salt
echo "base:
  '*':
    - common_packages
  'roles:elasticsearch':
    - match: grain
    - elasticsearch" > top.sls

echo "common_packages:
    pkg.installed:
        - names:
            - git
            - tmux
            - tree" > common_packages.sls

mkdir elasticsearch && cd elasticsearch
echo "# Elasticsearch configuration for {{ grains['fqdn'] }}
# Cluster: {{ grains['elasticsearch']['cluster'] }}

cluster.name: {{ grains['elasticsearch']['cluster'] }}
node.name: '{{ grains['fqdn'] }}'
node.master: true
node.data: false
discovery.zen.ping.multicast.enabled: false
discovery.zen.ping.unicast.hosts: ['{{ grains['fqdn'] }}']" > elasticsearch.yml

echo "Download Oracle JDK:
    cmd.run:
        - name: 'wget --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.rpm'
        - cwd: /home/$adminUsername/
        - runas: root
        - onlyif: if [ -f /home/$adminUsername/jdk-8u101-linux-x64.rpm ]; then exit 1; else exit 0; fi;

Install Oracle JDK:
    cmd.run:
        - name: yum install -y /home/$adminUsername/jdk-8u101-linux-x64.rpm
        - onlyif: if yum list installed jdk-8u101 >/dev/null 2>&1; then exit 1; else exit 0; fi;

elasticsearch_repo:
    pkgrepo.managed:
        - humanname: Elasticsearch Official Centos Repository
        - name: elasticsearch
        - baseurl: https://packages.elastic.co/elasticsearch/1.7/centos
        - gpgkey: https://packages.elastic.co/GPG-KEY-elasticsearch
        - gpgcheck: 1

elasticsearch:
    pkg:
        - installed
        - require:
            - pkgrepo: elasticsearch_repo

    service:
        - running
        - enable: True
        - require:
            - pkg: elasticsearch
            - file: /etc/elasticsearch/elasticsearch.yml

/etc/elasticsearch/elasticsearch.yml:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - source: salt://elasticsearch/elasticsearch.yml" > init.sls

cd ..
salt '*' state.highstate
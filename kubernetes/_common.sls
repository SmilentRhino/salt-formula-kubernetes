{%- from "kubernetes/map.jinja" import common with context %}

kubernetes_pkgs:
  pkg.installed:
  - names: {{ common.pkgs }}

{%- if common.network.get('engine', 'none') == 'flannel' %}
flannel-tar:
  archive:
    - extracted
    - user: root
    - name: /usr/local/src
    - makedirs: True
    - source: https://storage.googleapis.com/kubernetes-release/flannel/flannel-0.5.5-linux-amd64.tar.gz
    - tar_options: v
    - source_hash: md5=972c717254775bef528f040af804f2cc
    - archive_format: tar
    - if_missing: /usr/local/src/flannel/flannel-0.5.5/
{%- endif %}

{%- if common.hyperkube is defined %}
/tmp/hyperkube:
  file.directory:
    - user: root
    - group: root

hyperkube-copy:
  cmd.run:
    - name: docker run --rm -v /tmp/hyperkube:/tmp/hyperkube --entrypoint cp {{ common.hyperkube.image }} -vr /hyperkube /tmp/hyperkube
    - require:
      - file: /tmp/hyperkube
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

/usr/bin/hyperkube:
  file.managed:
    - source: /tmp/hyperkube/hyperkube
    - mode: 751
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: hyperkube-copy
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

/usr/bin/kubectl:
  file.symlink:
    - target: /usr/bin/hyperkube
    - require:
      - file: /usr/bin/hyperkube
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

{%- if common.addons.get('virtlet', {}).get('enabled') %}
/tmp/criproxy:
  file.directory:
    - user: root
    - group: root

copy-criproxy-bin:
  cmd.run:
    - name: docker run --rm -v /tmp/criproxy/:/tmp/criproxy/ --entrypoint cp {{ common.addons.virtlet.image }} -vr /criproxy /tmp/criproxy
    - require:
      - file: /tmp/criproxy
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

/usr/bin/criproxy:
  file.managed:
    - source: /tmp/criproxy/criproxy
    - mode: 750
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: copy-criproxy-bin
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

/etc/criproxy:
  file.directory:
    - user: root
    - group: root
    - mode: 0750

/etc/criproxy/kubelet.conf:
  file.managed:
    - source: salt://kubernetes/files/virtlet/kubelet.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 640

/etc/systemd/system/criproxy.service:
  file.managed:
    - source: salt://kubernetes/files/systemd/criproxy.service
    - template: jinja
    - user: root
    - group: root
    - mode: 755

criproxy_service:
  service.running:
  - name: criproxy
  - enable: True
  - watch:
    - file: /etc/systemd/system/criproxy.service
    - file: /etc/criproxy/kubelet.conf
    - file: /etc/criproxy
    - file: /usr/bin/criproxy
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}

{%- endif %}

/etc/systemd/system/kubelet.service:
  file.managed:
    - source: salt://kubernetes/files/systemd/kubelet.service
    - template: jinja
    - user: root
    - group: root
    - mode: 644

/etc/kubernetes/config:
  file.absent

{%- if not pillar.kubernetes.pool is defined %}

/etc/default/kubelet:
  file.managed:
  - source: salt://kubernetes/files/kubelet/default.master
  - template: jinja
  - user: root
  - group: root
  - mode: 644

/etc/kubernetes/kubelet.kubeconfig:
  file.managed:
    - source: salt://kubernetes/files/kubelet/kubelet.kubeconfig.master
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

{%- else %}

/etc/default/kubelet:
  file.managed:
  - source: salt://kubernetes/files/kubelet/default.pool
  - template: jinja
  - user: root
  - group: root
  - mode: 644

/etc/kubernetes/kubelet.kubeconfig:
  file.managed:
    - source: salt://kubernetes/files/kubelet/kubelet.kubeconfig.pool
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

{%- endif %}

manifest_dir_create:
  file.directory:
    - makedirs: true
    - name: /etc/kubernetes/manifests
    - user: root
    - group: root
    - mode: 0751

kubelet_service:
  service.running:
  - name: kubelet
  - enable: True
  - watch:
    - file: /etc/default/kubelet
    - file: /usr/bin/hyperkube
    - file: /etc/kubernetes/kubelet.kubeconfig
    - file: manifest_dir_create
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}

{%- if common.logrotate is defined %}
/etc/logrotate.d/kubernetes:
  file.managed:
    - source: salt://kubernetes/files/logrotate
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - defaults:
      logfile: {{ common.logrotate }}

{% endif %}
{% endif %}

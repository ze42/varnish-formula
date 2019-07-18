{% from "varnish/ng/map.jinja" import varnish_settings with context %}
include:
  - .service

varnish_multi_instances_unit_placeholder:
  file.managed:
  - name: /etc/systemd/system/varnish@.service
  - makedirs: True
  - contents: |
      [Unit]
      Description = Varnish - %i - placeholder for .d config
  - require:
    - file: varnish_multi_instances_unit_base
    - file: varnish_multi_instance_template

varnish_multi_instances_unit_base:
  file.symlink:
  - name: /etc/systemd/system/varnish@.service.d/00-base.conf
  - target: /lib/systemd/system/varnish.service
  - makedirs: True
  - require:
    - service: varnish.service

varnish_multi_instance_template:
  file.managed:
  - name: /etc/systemd/system/varnish@.service.d/10-template.conf
  - source: salt://{{ slspath }}/files/varnish-unit.conf
  - makedirs: True
  - require:
    - service: varnish.service

varnish instances service.systemctl_reload:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: varnish_multi_instance_template
      - file: varnish_multi_instances_unit_base
      - file: varnish_multi_instances_unit_placeholder

{% for instance, options in varnish_settings.get('instances', {}).items() %}
varnish {{ instance }} vcl template:
  file.managed:
  - name: {{ options.config }}
  - replace: False
  - unless: test -f {{ options.config }}
  - source: salt://varnish/files/default/etc/varnish/default.vcl.jinja
  - template: jinja
  - user: {{ options.get('user') }}
  - group: {{ options.get('group') }}
  - makedirs: True
  - dir_mode: 2755
  - mode: {{ options.get('mode', '644') }}
  - require:
    - service: varnish.service
  - require_in:
    - service: varnish {{ instance }} service

varnish {{ instance }} vcl:
  file.symlink:
  - name: /etc/varnish/{{instance}}.vcl
  - target: {{ options.config }}
  - require:
    - service: varnish.service
  - require_in:
    - service: varnish {{ instance }} service

varnish {{ instance }} defaults:
  file.managed:
  - name: /etc/default/varnish-{{ instance }}
  - source: salt://{{ slspath }}/files/varnish-instance.jinja 
  - template: jinja
  - context:
      config: {{ options|json }}
  - require:
    - service: varnish.service
  - require_in:
    - service: varnish {{ instance }} service

varnish {{ instance }} secret:
  file.managed:
  - name: /etc/varnish/secret-{{ instance }}
  - replace: False
  - source: salt://{{ slspath }}/files/uuid.jinja
  - template: jinja
  - user: root
  - group: {{ options.get('group', 'root') }}
  - mode: 440
  - require:
    - service: varnish.service
  - require_in:
    - service: varnish {{ instance }} service

varnish {{ instance }} service:
  service.running:
  - name: varnish@{{ instance }}
  - enable: True
  - reload: True
  - require:
    - module: varnish instances service.systemctl_reload
  module.run:
  - name: test.sleep
  - length: 5
  - onchanges:
    - service: varnish {{ instance }} service
{% endfor %}

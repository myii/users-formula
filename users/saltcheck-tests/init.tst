# -*- coding: utf-8 -*-
# vim: ft=sls

{%- set users = salt['pillar.get']('users', {}) %}

{%- set used_sudo = [] %}
{%- set used_googleauth = [] %}
{%- set used_user_files = [] %}
{%- set used_polkit = [] %}

{%- for group, setting in salt['pillar.get']('groups', {}).items() %}
{%-   if setting.absent is defined and setting.absent or setting.get('state', "present") == 'absent' %}

validate_users_group_absent_{{ group }}:
  module_and_function: group.info
  args:
    - {{ group }}
  assertion: assertEqual
  expected-return: {}

{%-   else %}

{%-     for section in ['gid'] %}
{%-       set assertion = 'assertEqual' %}
{%-       set expected = setting.get(section, '') %}
{%-       if not expected %}
{%-         set assertion = 'assertGreater' if setting.get('system', False) else 'assertLessEqual' %}
{%-         set expected = 1000 %}
{%-       endif %}
validate_users_group_present_{{ group }}_{{ section }}:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: {{ assertion }}
  assertion_section: '{{ section }}'
  expected-return: '{{ expected }}'
{%-     endfor %}

{%-     for section in ['members'] %}
{%-       for member in (setting.get('addusers', []) + setting.get('members', [])) %}
validate_users_group_present_{{ group }}_{{ section }}_{{ member }}_present:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: assertIn
  assertion_section: '{{ section }}'
  expected-return: '{{ member }}'
{%-       endfor %}
{%-       for member in setting.get('delusers', []) %}
validate_users_group_present_{{ group }}_{{ section }}_{{ member }}_absent:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: assertNotIn
  assertion_section: '{{ section }}'
  expected-return: '{{ member }}'
{%-       endfor %}
{%-     endfor %}

{%-   endif %}
{%- endfor %}

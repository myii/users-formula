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
{%-       for status, options in {
              'present': {
                  'assertion': 'assertIn',
                  'gp_settings': [
                      'addusers',
                      'members',
                  ],
              },
              'absent': {
                  'assertion': 'assertNotIn',
                  'gp_settings': [
                      'delusers',
                  ],
              },
          }.items() %}
{%-         set members = [] %} 
{%-         for gp_setting in options.gp_settings %} 
{%-           for member in setting.get(gp_setting, []) %} 
{%-             do members.append(member) %} 
{%-           endfor %} 
{%-         endfor %} 
{%-         for member in members %} 
validate_users_group_present_{{ group }}_{{ section }}_{{ member }}_{{ status }}:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: {{ options.assertion }}
  assertion_section: '{{ section }}'
  expected-return: '{{ member }}'
{%-         endfor %}
{%-       endfor %}
{%-     endfor %}

{%-   endif %}
{%- endfor %}

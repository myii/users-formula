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

{#-     Check `gid` for each group that is present #}
{%-     set section = 'gid' %}
{%-     set conf = {
            'default': {
                'assertion': 'assertEqual',
                'expected': setting.get(section, ''),
            },
            'alt': {
                'assertion': 'assertGreater' if setting.get('system', False) else 'assertLessEqual',
                'expected': 1000,
            },
          } %}
{%-     set use_conf = conf.default %}
{%-     if not use_conf.expected %}
{%-       set use_conf = conf.alt %}
{%-     endif %}
validate_users_group_present_{{ group }}_{{ section }}:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: {{ use_conf.assertion }}
  assertion_section: '{{ section }}'
  expected-return: '{{ use_conf.expected }}'

{#-     Check `members` present & absent for each group that is present #}
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

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
{%-     set section = 'members' %}
{%-     set conf = {
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
        } %}
{%-     for status, options in conf.items() %}
{%-       set members = [] %} 
{%-       for gp_setting in options.gp_settings %} 
{%-         for member in setting.get(gp_setting, []) %} 
{%-           do members.append(member) %} 
{%-         endfor %} 
{%-       endfor %} 
{%-       for member in members %} 
validate_users_group_present_{{ group }}_{{ section }}_{{ member }}_{{ status }}:
  module_and_function: group.info
  args:
    - '{{ group }}'
  assertion: {{ options.assertion }}
  assertion_section: '{{ section }}'
  expected-return: '{{ member }}'
{%-       endfor %}
{%-     endfor %}

{%-   endif %}
{%- endfor %}

{#- ... #}
{%- for name, user in pillar.get('users', {}).items() if user.absent is not defined or not user.absent %}
{%-   if user == None %}
{%-     set user = {} %}
{%-   endif %}
{%-   if 'sudoonly' in user and user['sudoonly'] %}
{%-     do user.update({'sudouser': True}) %}
{%-   endif %}
{%-   if 'sudouser' in user and user['sudouser'] %}
{%-     do used_sudo.append(1) %}
{%-   endif %}
{%-   if 'google_auth' in user %}
{%-     do used_googleauth.append(1) %}
{%-   endif %}
{%-   if salt['pillar.get']('users:' ~ name ~ ':user_files:enabled', False) %}
{%-     do used_user_files.append(1) %}
{%-   endif %}
{%-   if user.get('polkitadmin', False) == True %}
{%-     do used_polkit.append(1)  %}
{%-   endif %}
{%- endfor %}

{%- for name, user in pillar.get('users', {}).items() if user.absent is not defined or not user.absent %}
{%-   if user == None %}
{%-     set user = {} %}
{%-   endif %}
{%-   set current = salt.user.info(name) %}
{%-   set home = user.get('home', current.get('home', "/home/%s" % name)) %}
{%-   set createhome = user.get('createhome', users.get('createhome')) %}
{%-   if 'prime_group' in user and 'name' in user['prime_group'] %}
{%-     set user_group = user.prime_group.name %}
{%-   else %}
{%-     set user_group = name %}
{%-   endif %}

{%-   if not ('sudoonly' in user and user['sudoonly']) %}
{%-     for group in user.get('groups', []) %}
{%-       set use_conf = {
              'assertion': 'assertIn',
              'expected': group,
          } %}
validate_users_{{ name }}_{{ group }}_group:
  module_and_function: user.list_groups
  args:
    - '{{ name }}'
  assertion: {{ use_conf.assertion }}
  expected-return: '{{ use_conf.expected }}'
{%-     endfor %}

{#- In case home subfolder doesn't exist, create it before the user exists #}
{%-     if createhome %}
{%-       set use_conf = {
              'assertion': 'assertTrue',
          } %}
validate_users_{{ name }}_user_prereq:
  module_and_function: file.directory_exists
  args:
    - '{{ salt['file.dirname'](home) }}'
  assertion: {{ use_conf.assertion }}
{%-     endif %}


{%-   endif %}
{%- endfor %}

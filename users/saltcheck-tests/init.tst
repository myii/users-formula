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
{%-     set use_conf = {
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
{%-     for status, options in use_conf.items() %}
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

validate_users_{{ name }}_user_file_directory_exists:
  module_and_function: file.directory_exists
  args:
    - '{{ home }}'
  assertion: {{ use_conf.assertion }}

{%-       set use_conf = {
              'user': user.get('homedir_owner', name),
              'group': user.get('homedir_group', user_group),
              'mode': user.get('user_dir_mode', '0750'),
          } %}
{%-       for conf_key, conf_val in use_conf.items() %}
validate_users_{{ name }}_user_file_directory_{{ conf_key }}:
  module_and_function: file.get_{{ conf_key }}
  args:
    - '{{ home }}'
  assertion: assertEqual
  expected-return: '{{ conf_val }}'
{%-       endfor %}
{%-     endif %}

validate_users_{{ name }}_user_file_directory_group_present:
  module_and_function: user.primary_group
  args:
    - '{{ name }}'
  assertion: assertEqual
  expected-return: '{{ user_group }}'

{%-     set use_conf = {
            'shell': user.get('shell',
                       current.get('shell',
                         users.get('shell',
                           '/bin/bash'))),
            'uid': user.get('uid', ''),
            'gid': user.get('prime_group', {}).get('gid',
                     user.get('prime_group', {}).get('name',
                       '')),
            'fullname': user.get('fullname', ''),
            'roomnumber': user.get('roomnumber', ''),
            'workphone': user.get('workphone', ''),
            'homephone': user.get('homephone', ''),
        } %}
{%-     for conf_key, conf_val in use_conf.items() if conf_val %}
validate_users_{{ name }}_user_{{ conf_key }}:
  module_and_function: user.info
  args:
    - '{{ name }}'
  assertion: assertEqual
  assertion_section: '{{ conf_key }}'
  expected-return: '{{ conf_val }}'
{%-     endfor %}

{#-     SSH tests #}
{%-     if 'ssh_keys' in user or
           'ssh_auth' in user or
           'ssh_auth_file' in user or
           'ssh_auth_pillar' in user or
           'ssh_auth.absent' in user or
           'ssh_config' in user %}
{%-       set dir = home ~ '/.ssh' %}
{%-       set use_conf = {
              'user': name,
              'group': user_group,
              'mode': '0700',
          } %}
validate_user_keydir_{{ name }}_file_directory_exists:
  module_and_function: file.directory_exists
  args:
    - '{{ dir }}'
  assertion: assertTrue

{%-       for conf_key, conf_val in use_conf.items() %}
validate_user_keydir_{{ name }}_file_directory_{{ conf_key }}:
  module_and_function: file.get_{{ conf_key }}
  args:
    - '{{ dir }}'
  assertion: assertEqual
  expected-return: '{{ conf_val }}'
{%-       endfor %}
{%-     endif %}


{%-   endif %}
{%- endfor %}

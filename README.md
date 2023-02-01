## zabbix-ldap-sync -- Sync your Zabbix users with LDAP directory server

The *zabbix-ldap-sync* script is used for keeping your Zabbix users in sync with an LDAP directory server.

It can automatically import existing LDAP groups and users into Zabbix, thus making it easy for you to keep your Zabbix users in sync with LDAP.

Maintained by Marc Schöchlin <ms@256bit.org>

This project moved to https://github.com/zabbix-tooling/zabbix-ldap-sync to ease collaboration of developers.
You can switchover your current git clone byexecuting the follwing command:
```
git remote set-url origin git@github.com:zabbix-tooling/zabbix-ldap-sync.git # or
git remote set-url origin https://github.com/zabbix-tooling/zabbix-ldap-sync.git
```

## Requirements

* Python 3.x.x
* [pyldap](https://pypi.python.org/pypi/pyldap/)
* [pyzabbix](https://github.com/lukecyca/pyzabbix)
* [docopt](https://github.com/docopt/docopt)
* Zabbix 5.2 (works also for older releases)

You also need to have your Zabbix Frontend configured to authenticate against an AD/LDAP directory server.
(using http or ldap-auth)

Check the official documentation of Zabbix on how to 
[configure Zabbix to authenticate against an AD/LDAP directory server](https://www.zabbix.com/documentation/current/en/manual/web_interface/frontend_sections/administration/authentication)

### Setup virtualenv

* Clone the git repository
  ```
  git clone https://github.com/zabbix-tooling/zabbix-ldap-sync.git
  cd zabbix-ldap-sync
  ```
* Install the basic tools for virtualenv and create one
  * Debian and Ubuntu Systems:
    ```
    sudo apt-get install python-dev virtualenv libpython3.*-dev libldap2-dev libsasl2-dev
    virtualenv -p python3 venv
    ```
  * CentOS and Redhat Systems:
    ```
    sudo yum install python3-devel openldap-devel
    python3 -m venv venv
    ```
* Activate the virtualenv and install the dependencies of the project
  ```
  source venv/bin/activate
  pip install -r requirements.txt
  ```
* Run the tool
  ```
  ./zabbix-ldap-sync -h
  ```


## Configuration

In order to use the *zabbix-ldap-sync* script we need to create a configuration file describing the various LDAP and Zabbix related config entries.

### Config file sections

*RECOMMENDATION:*  Use a ldap client like [Apache Directory Studio](https://directory.apache.org/studio/) to test the ldap connection, filters and to inspect available attributes. The flag `--verbose` helps to get the ldap filters calculated by the script.

#### [ldap]
* `type` - Select type of ldap server, can be `activedirectory` or `openldap`
* `uri` - URI of the LDAP server, including port
* `base` - Base `Distinguished Name`
* `binduser` - LDAP user which has permissions to perform LDAP search
* `bindpass` - Password for LDAP user
* `groups` - LDAP groups to sync with Zabbix
   * supports wildcard - TESTED ONLY with Active Directory, see Command-line arguments
   * roleids or rolename for the created users can be encoded with groups (`<goupname>:<numeric role id/name>`)
* `media` - Name of the LDAP attribute of user object, that will be used to set `Send to` property of Zabbix user media. If entry is not used, no media synchronizastion is made. Common value is `mail`.
* `ignore_tls_errors` - If set to true, tls connection problems are ignored (you should use this only for testing)

#### [ad]
* `filtergroup` = The ldap filter to get group in ActiveDirectory mode, by default `(&(objectClass=group)(name=%s))`
* `filteruser` = The ldap filter to get the users in ActiveDirectory mode, by default `(objectClass=user)(objectCategory=Person)`
* `filterdisabled` = The filter to get the disabled user in ActiveDirectory mode, by default `(!(userAccountControl:1.2.840.113556.1.4.803:=2))`
* `filtermemberof` = The filter to get memberof in ActiveDirectory mode, by default `(memberOf:1.2.840.113556.1.4.1941:=%s)`
* `groupattribute` = The attribute used for membership in a group in ActiveDirectory mode, by default `member`
* `userattribute` = The attribute for users in ActiveDirectory mode `sAMAccountName`

#### [openldap]
* `type` = The storage mode for group and users can be `posix` or `groupofnames` 
* `filtergroup` = The ldap filter to get group in OpenLDAP mode, by default `(&(objectClass=posixGroup)(cn=%s))`
* `filteruser` = The ldap filter to get the users in OpenLDAP mode, by default `(&(objectClass=posixAccount)(uid=%s))`
* `groupattribute` = The attribute used for membership in a group in OpenLDAP mode, by default `memberUid`
* `userattribute` = The attribute for users in openldap mode, by default `uid`

#### [zabbix]
* `server` - Zabbix URL
* `username` - Zabbix username. This user must have permissions to add/remove users and groups. Typically, this would be `Zabbix Admin` account.
* `password` - Password for Zabbix user
* `apitoken` - Zabbix API token (Available since Zabbix 5.4)
* `auth` - can be `http` (for basic auth), `webform` (for regular form based login) or `token` (for API token).
   If `token` is used, `username` and `password` are ignored. Likewise, `apitoken` is ignored for `http` and `webform`.
* `alldirusergroup` - A group in Zabbix where to put all users created from the ldap directory.<br>
   Create this group before using this tool and give members of this group no permissions to your zabbix instance.<br>
   If a user is not available anymore by the directory, the user remains in this single group. This allows us to keep the audit trail of zabbix consistent. 
   If you do not define this property, users are not assigned to that group.
* `ignore_tls_errors` - If set to true, tls connection problems are ignored (you should use this only for testing)

#### [user]

Allows to override various properties for Zabbix users created by script. See [User object](https://www.zabbix.com/documentation/current/en/manual/api/reference/user/object) in Zabbix API documentation for available properties. If section/property doesn't exist, defaults are:

 * `role = User role` - User numeric role id or role name, for zabbix <= 4.4 use ["type"](https://www.zabbix.com/documentation/4.4/en/manual/api/reference/user/object) with a suitable value (i.e. "1")
 * `show_password` - Display passwords. Possible values: `true` or `false` 

#### [media]
Allows to override media type and various properties for Zabbix media for users created by script.

* `decription` - Description of Zabbix media (`Email`, `Jabber`, `SMS`, etc...). This entry is optional, default value is `Email`.

You can configure additional properties in this section. See [Media object](https://www.zabbix.com/documentation/current/en/manual/api/reference/user/object) in Zabbix API documentation for available properties. If this section/property doesn't exist, defaults fro additional properties are:

* `active = 0` - Whether the media is enabled. Possible values: `0`- enabled; `1` - disabled.
* `period = 1-7,00:00-24:00` - Time when the notifications can be sent as a [time period](https://www.zabbix.com/documentation/current/en/manual/appendix/time_period).
* `onlycreate = true` -  Process media only on newly created users if this is set to `true`. 
* `severity = Disaster,High,Average,Warning` - A list of severities to send notifications about, seperated by comma (alternative: the numeric bitmap value).


## Configuration file example

See [example config file](zabbix-ldap.conf.example), create a copy of this and modify it according to your needs.

## Command-line arguments


    Usage: zabbix-ldap-sync [-lsrwdn] [--verbose] -f <config>
       zabbix-ldap-sync -v
       zabbix-ldap-sync -h

    Options:
      -h, --help                    Display this usage info
      -v, --version                 Display version and exit
      -l, --ldap-accountids         Do not make changes to ldap account id names
      -s, --skip-disabled           Skip disabled AD users
      -r, --recursive               Resolves AD group members recursively (i.e. nested groups)
      -w, --wildcard-search         Search AD group with wildcard (e.g. R.*.Zabbix.*) - TESTED ONLY with Active Directory
      -d, --delete-orphans          Delete Zabbix users that don't exist in a LDAP group
      -a, --remove-absent           Remove Zabbix users from group that don't exist in a LDAP group
      -n, --no-check-certificate    Don't check Zabbix server certificate
      --verbose                     Print debug message from ZabbixAPI
      --dryrun                      Just simulate zabbix interaction
      -f <config>, --file <config>  Configuration file to use


## Importing LDAP users into Zabbix

Now that we have the above mentioned configuration file created, let's import our groups and users from LDAP to Zabbix.

	$ ./zabbix-ldap-sync -f /path/to/zabbix-ldap.conf
	
Once the script completes, check your Zabbix Frontend to verify that users are successfully imported.

To sync different LDAP groups with different options, create separate config file for each group and run `zabbix-ldap-sync`:

	$ ./zabbix-ldap-sync -f /path/to/zabbix-ldap-admins.conf
	$ ./zabbix-ldap-sync -f /path/to/zabbix-ldap-users.conf

You would generally be running the above scripts on regular basis, say each day from `cron(8)` in order to make sure your Zabbix system is in sync with LDAP.

## Using Docker Compose

Create the config directory:

	$ mkdir config

Copy the config to directory with `zabbix-ldap.conf` name, example:

	$ cp ./zabbix-ldap.conf.example config/zabbix-ldap.conf

You can change the docker-compose volume mount point or config file name on [docker-compose.yml](docker-compose.yml)

Finally run the docker-compose:

	$ docker-compose up

To run on detached mode use the param `-d`:

	$ docker-compose up -d

# Open Developent Tasks

This tool works for years now, but from a view of serious software development this piece of code still needs major refactorings.
Major refactoring tends to break things which are not available in my testing environment.

Starting from the original implementation, some things have already been improved, extended and simplified.
In my busy everyday life, I have unfortunately not yet found time for the following topics.

Contributions are very welcome, especially for the following topics:

- eliminate the need to pass around configuration values between classes
- eliminate the need of different configuration sections for ldap 'openldap' and 'ad'
- isolate configuration logic in lib/zabbixldapconf.py
- add software tests
- add azure-ad/graphapi support


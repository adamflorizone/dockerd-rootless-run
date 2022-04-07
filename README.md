# dockerd-rootless-run
Runs useful commands under docker only (such as nodejs) with readonly as default

``` !!! This script will install (rootless) docker by default if not found !!!```

1) download dockerd-rootless-run to your bin. 
2) Run dockerd-rootless-run and it will make syslinks for useful commands

## Commands after install
``` *-rw version enables write mode. By default all commands have no write access an can only read from current dir ```
* nodejs (nodejs-rw)
* npm (npm-rw)
* npx (npx-rw)

## Examples
```
mkdir /tmp/testapp
cd /tmp/testapp
npm-rw init
# Now configure your test application
echo 'console.log("helloworld!");'>index.js
node index
```

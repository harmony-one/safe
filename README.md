# Harmony - safe gnosis wallet
## How to build app
 1. Create apis.bundle
```sh
cd Multisig
cd Cross-layer
cd Configuration
mkdir apis.bundle
```

2. Add Infura API Key
Add Infura API Key to "INFURA_API_KEY" in apis-staging.example and apis-prod.example in Multisig > Cross-layer > Configuration
3. Run Encryption
Create Encryption of those staging and prod examples using secconfig.
Run:
```sh
bin/secconfig encrypt Multisig/Cross-layer/Configuration/apis-staging.example.json Multisig/Cross-layer/Configuration/apis.bundle/apis-staging.enc.json
```
Then copy the key from the output and run where "" is replaced with that output:
```
export CONFIG_KEY_STAGING=""
```
Now run:
```
bin/secconfig encrypt Multisig/Cross-layer/Configuration/apis-prod.example.json Multisig/Cross-layer/Configuration/apis.bundle/apis-prod.enc.json
```
and do the same thing for:
```
export CONFIG_KEY_PROD=""
```

4. Configure
```
bin/configure.sh
```

Don't commit apis-staging.example and apis-prod.example to git.

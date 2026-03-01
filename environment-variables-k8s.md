This file defines the environment variables that we use in this repo. 

This includes the following environment variables - which are set with the help of `tplenv`:

1. For the development pod, we use the following container image: $CLI_IMAGE
   The default is "registry.scontain.com/workshop/scone".
2. The Kubernetes namespace that we use to run the SCONE development pod: $CLI_NAMESPACE
   The default is "scone-tools".
3. The SCONE version is stored in environment variable ${SCONE_VERSION}
   Right now, the default is 7.0.0-alpha.1: 
4. $REGISTRY contains the name of the registry. By default, we set this to `registry.scontain.com`.

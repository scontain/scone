This file defines the environment variables that we use in this repo. 

This includes the following environment variables - which are set with the help of `tplenv`:

1. For the development pod, we use the following container image: $CLI_IMAGE
   Save the untagged default `registry.scontain.com/workshop/scone`; deployment appends the selected SCONE version.
2. The Kubernetes namespace that we use to run the SCONE development pod: $CLI_NAMESPACE
   The default is "scone-tools".
3. The SCONE version is stored in environment variable ${SCONE_VERSION}
   The default is the version in `stable.txt`.
Registry settings are resolved separately from `toolbox.credentials.md` using the ignored `Values.credentials.yaml`.

## Configuration for setting up a firedrake jhub demonstrator

# Dockerfile.singleuser

This Dockerfile builds a single-user session image from the scipy notebook base image, installing firedrake and setting up an ipython/jhub kernel which is available to select in the user session.

# deploy.sh

This script is run from a command line with azure and kubernetes command line tools available. It assumes that the session is already logged in to azure, and has the correct subscription selected. 

The script is far from foolproof as it stands. In particular, the later stages tend to fail as a result of commands returning before their deployments are complete, leading to subsequent commands not finding expected resources. Regard it as more of a documentation of a command set than necessarily a script to run as-is.

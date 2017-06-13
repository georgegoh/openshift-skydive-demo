# openshift-skydive-demo

## How to use

1. Log in to the cluster with an admin user.
2. Run the *create_skydive.sh* script. This script takes ONE argument - 
   which it appends to the new project being created. For example, an
   invocation of 'create_skydive.sh foo' will create a new project with
   the name 'skydive-demo-foo'
3. After some time, the route exposed by this service will be ready.
   Check with 'oc get route'.

## References

See https://github.com/skydive-project/skydive/blob/master/contrib/kubernetes/skydive.yaml

#!/bin/sh

USERID=$1
echo "User ID ${USERID}"

PROJECTNAME=skydive-demo-${USERID}

oc new-project ${PROJECTNAME}
oc -n ${PROJECTNAME} adm policy add-scc-to-user privileged -z default
oc patch limits/${PROJECTNAME}-core-resource-limits -p 'spec:
  limits:
  - default:
      cpu: 500m
      memory: 2Gi
    defaultRequest:
      cpu: 50m
      memory: 256Mi
    max:
      memory: 3Gi
    min:
      memory: 50Mi
    type: Container
  - max:
      memory: 4Gi
    min:
      memory: 6Mi
    type: Pod'


TEMPFILE=`mktemp /tmp/tmp-skydive-${USERID}-XXX.yaml`

cat > ${TEMPFILE} << SKYDIVETEMPLATE
apiVersion: v1
kind: Service
metadata:
  name: skydive-analyzer
  labels:
    app: skydive-analyzer
spec:
  type: NodePort
  ports:
  - port: 8082
    name: api
  - port: 8082
    name: protobuf
    protocol: UDP
  - port: 2379
    name: etcd
  - port: 9200
    name: es
  selector:
    app: skydive
    tier: analyzer
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: skydive-analyzer
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: skydive
        tier: analyzer
    spec:
      containers:
      - name: skydive-analyzer
        image: skydive/skydive
        args:
        - analyzer
        - --listen=0.0.0.0:8082
        ports:
        - containerPort: 8082
        - containerPort: 8082
          protocol: UDP
        - containerPort: 2379
        env:
        - name: SKYDIVE_ANALYZER_STORAGE_BACKEND
          value: elasticsearch
        - name: SKYDIVE_GRAPH_BACKEND
          value: elasticsearch
        - name: SKYDIVE_ETCD_LISTEN
          value: 0.0.0.0:2379
      - name: skydive-elasticsearch
        image: elasticsearch:2
        ports:
        - containerPort: 9200
        securityContext:
          privileged: true
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: skydive-agent
spec:
  template:
    metadata:
      labels:
        app: skydive
        tier: agent
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: skydive-agent
        image: skydive/skydive
        args:
        - agent
        ports:
        - containerPort: 8081
        env:
        - name: SKYDIVE_ANALYZERS
          value: "\$(SKYDIVE_ANALYZER_SERVICE_HOST):\$(SKYDIVE_ANALYZER_SERVICE_PORT_API)"
        securityContext:
          privileged: true
        volumeMounts:
        - name: docker
          mountPath: /var/run/docker.sock
        - name: run
          mountPath: /host/run
        - name: ovsdb
          mountPath: /var/run/openvswitch/db.sock
      volumes:
      - name: docker
        hostPath:
          path: /var/run/docker.sock
      - name: run
        hostPath:
          path: /var/run/netns
      - name: ovsdb
        hostPath:
          path: /var/run/openvswitch/db.sock
---
apiVersion: v1
kind: Route
metadata:
  name: route-skydive
spec:
  port:
    targetPort: api
  to:
    kind: Service
    name: skydive-analyzer
SKYDIVETEMPLATE

oc create -f ${TEMPFILE}

rm -f ${TEMPFILE}

